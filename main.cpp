#include <stdlib.h>
#include <iostream>
#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#define MAXTICKS 25
#define cout std::cout
#ifndef	TESTB_H
#define	TESTB_H

#define	TBASSERT(TB,A) do { if (!(A)) { (TB).closetrace(); } assert(A); } while(0);

template <class VA>	class BaseTestbench {
public:
	VA		*m_core;
	VerilatedVcdC*	m_trace;
	uint64_t	m_tickcount;

	BaseTestbench(void) : m_trace(NULL), m_tickcount(0l) {
		m_core = new VA;
		Verilated::traceEverOn(true);
		m_core->clk = 0;
		eval(); // Get our initial values set properly.
	}

	virtual ~BaseTestbench(void) {
		closetrace();
		delete m_core;
		m_core = NULL;
	}

	virtual	void	opentrace(const char *vcdname) {
		if (!m_trace) {
			m_trace = new VerilatedVcdC;
			m_core->trace(m_trace, 99);
			m_trace->open(vcdname);
		}
	}

	virtual	void	closetrace(void) {
		if (m_trace) {
			m_trace->close();
			delete m_trace;
			m_trace = NULL;
		}
	}

	virtual	void	eval(void) {
		m_core->eval();
	}

	virtual	void	tick(void) {
		m_tickcount++;

		// Make sure we have our evaluations straight before the top
		// of the clock.  This is necessary since some of the 
		// connection modules may have made changes, for which some
		// logic depends.  This forces that logic to be recalculated
		// before the top of the clock.
		eval();
		if (m_trace) m_trace->dump((vluint64_t)(10*m_tickcount-2));
		m_core->clk = 1;
		eval();
		if (m_trace) m_trace->dump((vluint64_t)(10*m_tickcount));
		m_core->clk = 0;
		eval();
		if (m_trace) {
			m_trace->dump((vluint64_t)(10*m_tickcount+5));
			m_trace->flush();
		}
	}

	virtual	void	reset(void) {
		m_core->reset = 1;
		tick();
		m_core->reset = 0;
		// printf("RESET\n");
	}

	unsigned long	tickcount(void) {
		return m_tickcount;
	}

	virtual bool isFinished(void) {
		return Verilated::gotFinish();
	}
};

#endif

int main(int argc, char **argv) {
	// Initialize Verilators variables
	Verilated::commandArgs(argc, argv);
	BaseTestbench<Vtop>* testBench = new BaseTestbench<Vtop>;

	testBench->opentrace("Out.vcd");

	testBench->reset();
	while (!testBench->isFinished() && testBench->tickcount() < MAXTICKS)
	{
		testBench->tick();
		if (testBench->m_core->memwrite)
		{
			cout << "DataAdress:" << testBench->m_core->dataadr << ". WrittenValue:" << testBench->m_core->writedata << std::endl;
			if(testBench->m_core->dataadr == 84 & testBench->m_core->writedata == 7)
			{
				cout << "7 was written to 84 memory cell" << std::endl;
			}
			else
			if(testBench->m_core->dataadr == 84 & testBench->m_core->writedata == 14)
			{
				cout << "14 (7 shifted by 1) was written to 85 memory cell\n" << std::endl;
			}
			else
			if(testBench->m_core->dataadr == 84 & testBench->m_core->writedata == 65536)
			{
				cout << " LUI command of 1 outputed:" << testBench->m_core->writedata << std::endl;
			}
			else 
			if(testBench->m_core->dataadr == 42 & testBench->m_core->writedata == 0)
			{
				cout << " SLTI outputed 0 (5000 really is less then 65536, let's be honest):" << testBench->m_core->writedata << std::endl;
				// break;
			}					
		}
	}

	cout << "Testbench simulation ended" << std::endl;
}