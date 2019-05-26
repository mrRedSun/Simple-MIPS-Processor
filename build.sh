verilator -cc --top-module top --trace -Wno-fatal mipstop.sv mips.sv mipsmem.sv mipsparts.sv --exe main.cpp;
make -j -C obj_dir -f VTop.mk;
cp memfile.dat obj_dir;