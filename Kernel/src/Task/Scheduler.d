module Task.Scheduler;
import Data.Address;
import Data.LinkedList;
import Task.Process;
import CPU.GDT;
import CPU.PIT;
import Task.Mutex.SpinLockMutex;

private extern (C) {
	extern __gshared ubyte KERNEL_STACK_START;
	ulong getRIP();
	void fpuEnable();
	void fpuDisable();
}
class Scheduler {
public:
	void Init() {
		processes = new LinkedList!Process();
		initIdle(); // PID 0
		initKernel(); // PID 1
		pidCounter = 2;
		current = initProcess;
	}

	void SwitchProcess(bool reschedule = true) {
		if (!current)
			return;
		ulong storeRBP = void;
		ulong storeRSP = void;
		asm {
			mov storeRBP[RBP], RBP;
			mov storeRSP[RBP], RSP;
		}
		ulong storeRIP = getRIP();
		if (storeRIP == SWITCH_MAGIC) // Swap is done
			return;

		current.active = false;
		with (current.threadState) {
			rbp = storeRBP;
			rsp = storeRSP;
			rip = storeRIP;
			if (fpuEnabled) {
				ubyte[] storeFPU = fpuStorage;
				asm {
					fxsave storeFPU;
				}
				fpuDisable();
			}
		}

		if (reschedule && current != idleProcess)
			processes.Add(current);
		doSwitching();
	}

	PID Fork() {
		// Clones everything
		return PID.max;
	}

	VirtAddress Join(PID p) {
		// Joins a finished process
		return VirtAddress(0);
	}

	PID Clone(VirtAddress function() func, VirtAddress stack = VirtAddress(0), string _name = current.name) {
		if(stack == 0)
			stack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;

		Process* process = new Process();
		with (process) {
			pid = getFreePid;
			name = _name.dup;
			uid = current.uid;
			gid = current.gid;

			threadState.rip = VirtAddress(func);
			threadState.rbp = VirtAddress(0);
			threadState.rsp = stack;
			threadState.fpuEnabled = current.threadState.fpuEnabled;
			threadState.paging = current.threadState.paging;

			image.stack = stack;

			state = ProcessState.Waiting;
			active = false;
		}

		processes.Add(process);
		return process.pid;
	}

	@property Process* CurrentProcess() {
		return current;
	}

private:
	enum StackSize = 0x1000;
	enum ulong SWITCH_MAGIC = 0xDEAD_C0DE;

	ulong pidCounter;
	bool initialized;
	LinkedList!Process processes;
	Process* current;

	Process* idleProcess;
	Process* initProcess;

	ulong getFreePid() {
		import IO.Log : log;

		if (pidCounter == ulong.max)
			log.Fatal("Out of pids!");
		return pidCounter++;
	}

	static void idle() {
		asm {
		start:
			sti;
			hlt;
			jmp start;
		}
	}

	void initIdle() {
		import Memory.Paging : GetKernelPaging;

		VirtAddress stack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		idleProcess = new Process();
		with (idleProcess) {
			pid = 0;
			name = "[Idle]";
			description = "Idle thread";
			uid = 0;
			gid = 0;
			threadState.rip = VirtAddress(&idle);
			threadState.rbp = stack;
			threadState.rsp = stack;
			threadState.fpuEnabled = false;
			threadState.paging = GetKernelPaging();

			image.stack = stack;

			state = ProcessState.Running;
		}
	}

	void initKernel() {
		import Memory.Paging : GetKernelPaging;

		current = initProcess = new Process();
		with (initProcess) {
			pid = 1;
			name = "Init";
			description = "The init process";
			uid = 0;
			gid = 0;

			threadState.rip = VirtAddress(0);
			threadState.rbp = VirtAddress(0);
			threadState.rsp = VirtAddress(0);
			threadState.fpuEnabled = false;
			threadState.paging = GetKernelPaging();

			image.stack = VirtAddress(&KERNEL_STACK_START) + 1 /*???*/ ;

			state = ProcessState.Running;
			active = true;
		}
	}

	Process* nextProcess() {
		if (processes.Length)
			return processes.Remove(0);
		else
			return idleProcess;
	}

	void doSwitching() {
		current = nextProcess();

		ulong storeRIP = current.threadState.rip;
		ulong storeRBP = current.threadState.rbp;
		ulong storeRSP = current.threadState.rsp;

		current.threadState.paging.Install();
		GDT.tss.RSP0 = current.image.stack;

		current.active = true;

		asm {
			mov RAX, RBP; // RBP will be overritten below

			mov RBX, storeRIP[RAX];
			mov RBP, storeRBP[RAX];
			mov RSP, storeRSP[RAX];
			mov RAX, SWITCH_MAGIC;
			sti;
			jmp RBX;
		}
	}

}

Scheduler GetScheduler() {
	import Data.Util : InplaceClass;

	__gshared Scheduler scheduler;
	__gshared ubyte[__traits(classInstanceSize, Scheduler)] data;
	if (!scheduler)
		scheduler = InplaceClass!Scheduler(data);
	return scheduler;
}
