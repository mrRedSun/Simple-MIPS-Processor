
// files needed for simulation:
//  mipstop.v
//  mipsmem.v
//  mips.v
//  mipsparts.v
`include "mipsparts.sv"

// single-cycle MIPS processor
module mips(input  logic        clk, reset,
            output logic [31:0] pc,
            input  logic [31:0] instr,
            output logic        memwrite,
            output logic [31:0] aluout, writedata,
            input  logic [31:0] readdata);

  logic        memtoreg, branch,
               pcsrc, zero,
               regdst, regwrite, jump;
  logic [3:0]  alucontrol;
  logic [1:0] alusrc;
  logic ltez;

  controller c(instr[31:26], instr[5:0], zero,
               memtoreg, memwrite, pcsrc,
               alusrc, regdst, regwrite, jump,
               alucontrol, ltez);
  datapath dp(clk, reset, memtoreg, pcsrc,
              alusrc, regdst, regwrite, jump,
              alucontrol,
              zero, pc, instr,
              aluout, writedata, readdata, ltez);
endmodule

module controller(input  logic [5:0] op, funct,
                  input  logic       zero,
                  output logic       memtoreg, memwrite,
                  output logic       pcsrc,
                  output logic [1:0] alusrc,
                  output logic       regdst, regwrite,
                  output logic       jump,
                  output logic [3:0] alucontrol,
                  input  logic       ltez);

  logic [1:0] aluop;
  logic       branch;
  logic       blez;

  maindec md(op, memtoreg, memwrite, branch,
             alusrc, regdst, regwrite, jump,
             aluop, blez);
  aludec  ad(funct, aluop, alucontrol);

  
  assign pcsrc = (branch & zero) | (blez & ltez);
endmodule

module maindec(input  logic [5:0] op,
               output logic       memtoreg, memwrite,
               output logic       branch, 
               output logic [1:0] alusrc,
               output logic       regdst, regwrite,
               output logic       jump,
               output logic [1:0] aluop,
               output logic       blez);

  logic [10:0] controls;

  assign {regwrite, regdst, alusrc,
          branch, memwrite,
          memtoreg, aluop, jump, blez} = controls;

  always_comb
    case(op)
      6'b000000: controls = 11'b11000001000; //Rtype
      6'b100011: controls = 11'b10010010000; //LW
      6'b101011: controls = 11'b00010100000; //SW
      6'b000100: controls = 11'b00001000100; //BEQ
      6'b001000: controls = 11'b10010000000; //ADDI
      6'b000010: controls = 11'b00000000010; //J
      6'b001010: controls = 11'b10010001100; //SLTI
      6'b001111: controls = 11'b10100000000; //LUI
      6'b000110: controls = 11'b00000000101; //BLEZ
      default:   controls = 11'bxxxxxxxxxxx; //???
    endcase
endmodule

module aludec(input  logic [5:0] funct,
              input  logic [1:0] aluop,
              output logic [3:0] alucontrol);

  always_comb
    case(aluop)
      2'b00: alucontrol <= 4'b0010;  // add
      2'b01: alucontrol <= 4'b1010; // sub
      2'b11: alucontrol <= 4'b1011; // slt
      default: case(funct)          // RTYPE
          6'b100000: alucontrol <= 4'b0010; // ADD
          6'b100010: alucontrol <= 4'b1010; // SUB
          6'b100100: alucontrol <= 4'b0000; // AND
          6'b100101: alucontrol <= 4'b0001; // OR
          6'b101010: alucontrol <= 4'b1011; // SLT
          6'b000000: alucontrol <= 4'b0100; // SLL
          default:   alucontrol <= 4'bxxxx; // ???
        endcase
    endcase
endmodule

module datapath(input  logic        clk, reset,
                input  logic        memtoreg, pcsrc,
                input  logic [1:0]  alusrc, 
                input  logic        regdst,
                input  logic        regwrite, jump,
                input  logic [3:0]  alucontrol,
                output logic        zero,
                output logic [31:0] pc,
                input  logic [31:0] instr,
                output logic [31:0] aluout, writedata,
                input  logic [31:0] readdata,
                output logic        ltez);

  logic [4:0]  writereg;
  logic [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
  logic [31:0] signimm, signimmsh;
  logic [31:0] upperimm;
  logic [31:0] srca, srcb;
  logic [31:0] result;
  logic [31:0] memdata;

  // next PC logic
  flopr #(32) pcreg(clk, reset, pcnext, pc);
  adder       pcadd1(pc, 32'b100, pcplus4);
  sl2         immsh(signimm, signimmsh);
  adder       pcadd2(pcplus4, signimmsh, pcbranch);
  mux2 #(32)  pcbrmux(pcplus4, pcbranch, pcsrc,
                      pcnextbr);
  mux2 #(32)  pcmux(pcnextbr, {pcplus4[31:28], 
                    instr[25:0], 2'b00}, 
                    jump, pcnext);

  // register file logic
  regfile     rf(clk, regwrite, instr[25:21],
                 instr[20:16], writereg,
                 result, srca, writedata);
  mux2 #(5)   wrmux(instr[20:16], instr[15:11],
                    regdst, writereg);
  mux2 #(32)  resmux(aluout, readdata,
                     memtoreg, result);
  signext     se(instr[15:0], signimm);
  upimm       ui(instr[15:0], upperimm); 

  // ALU logic
  mux3 #(32)  srcbmux(writedata, signimm,
                      upperimm, alusrc,
                      srcb);      // LUI

  alu         alu(.a(srca), .b(srcb), .f(alucontrol),
                  .shamt(instr[10:6]),
                  .y(aluout), .zero(zero), .ltez(ltez));
endmodule

module alu(
    input   logic [31:0] a, b,
    input   logic [3:0] f,
    input   logic [4:0] shamt,
    output  logic [31:0] y,
    output  logic zero, ltez, overflow
);
    logic [31:0] s, bout;
 
    assign bout = f[3] ? ~b : b;
    assign s = a + bout + f[3];
    always_comb
        case (f[2:0])
            3'b000: y <= a & bout;
            3'b001: y <= a | bout;
            3'b010: y <= s;
            3'b011: y <= s[31];
            3'b100: y <= (bout << shamt); 
        endcase
    assign zero = (y == 32'b0);
    assign ltez = zero | s[31];
    always_comb
        case (f[2:1])
            2'b01: overflow <= a[31] & b[31] & ~s[31] | ~a[31] & ~b[31] & s[31];
            2'b11: overflow <= ~a[31] & b[31] & s[31] |  a[31] & ~b[31] & ~s[31];
        default: overflow <= 1'b0;
    endcase
endmodule

