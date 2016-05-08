module Task.Scheduler;

import Data.Address;
import Data.LinkedList;
import Task.Thread;
import CPU.GDT;
import CPU.PIT;
import Task.Mutex.SpinLockMutex;

__gshared Scheduler scheduler;

class Scheduler {
public:
	this() {
		import Memory.Paging;

		threades = new LinkedList!Thread();

		current = kernelThread = new Thread(0, false, GetKernelPaging);
		mutex = new SpinLockMutex();
	}


	/// This function is only allowed to be called in a interrupt AKA only from the PIT
	void Schedule() {
		mutex.Lock();
		Thread prev = current;
		threades.MoveFrontToEnd();

		Thread next = threades.Get(0); // Need to get the variable on the stack for the assembly code to work
		current = next;
		if (!current)
			current = next = prev;

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

			mov Thread.KernelStack.offsetof[RBX], RSP;
			mov RSP, Thread.KernelStack.offsetof[RAX];
			cmp Thread.FirstTime.offsetof[RAX], 0;
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
			mutex.Unlock();
			asm {
				sti;
				ret;
			}
		}
		mutex.Unlock();
	}

	void AddThread(Thread Thread) {
		mutex.Lock();
		threades.Add(Thread);
		mutex.Unlock();
	}

	@property Thread CurrentThread() {
		return current;
	}

private:
	bool initialized;
	SpinLockMutex mutex;
	LinkedList!Thread threades;
	Thread current;

	Thread kernelThread;
}
