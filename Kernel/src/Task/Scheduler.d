module Task.Scheduler;

import Data.Address;
import Data.LinkedList;
import Task.Process;
import CPU.GDT;

__gshared Scheduler scheduler;

class Scheduler {
public:
	this() {
		import Memory.Paging;

		processes = new LinkedList!Process();

		current = kernelProcess = new Process(0, false, GetKernelPaging);
		counter = 1;
	}

	void SchedulerTick() {
		if (--counter > 0)
			return;
		counter = 1;

		Process prev = current;
		processes.Add(current);

		Process next = processes.Remove(0); // Need to get the variable on the stack for the assembly code to work
		current = next;

		if (next == prev)
			return;

		if (next.MemoryMap != prev.MemoryMap)
			next.MemoryMap.Install();

		asm {
			push RAX;
			push RBX;
			push RCX;
			push RDX;
			push RSI;
			push RDI;
			push RBP;
			push R8;
			push R9;
			push R10;
			push R11;
			push R12;
			push R13;
			push R14;
			push R15;

			mov RAX, next;
			mov RBX, prev;

			mov Process.KernelStack.offsetof[RBX], RSP;
			mov RSP, Process.KernelStack.offsetof[RAX];
			cmp Process.FirstTime.offsetof[RAX], 0;
			jne skip;

			pop R15;
			pop R14;
			pop R13;
			pop R12;
			pop R11;
			pop R10;
			pop R9;
			pop R8;
			pop RBP;
			pop RDI;
			pop RSI;
			pop RDX;
			pop RCX;
			pop RBX;
			pop RAX;

		skip:
			;
		}

		GDT.tss.RSP0 = VirtAddress(next.KernelStack + 0x1000 - 16);

		if (next.FirstTime) {
			next.FirstTime = false;
			asm {
				sti;
				ret;
			}
		}
	}

	void AddProcess(Process process) {
		processes.Add(process);
	}

	@property Process CurrentProcess() {
		return current;
	}

private:
	bool initialized;
	LinkedList!Process processes;
	Process current;
	ulong counter;

	Process kernelProcess;
}
