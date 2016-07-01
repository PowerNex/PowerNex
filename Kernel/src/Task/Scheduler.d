module Task.Scheduler;
import Data.Address;
import Data.LinkedList;
import Task.Process;
import CPU.GDT;
import CPU.PIT;
import Task.Mutex.SpinLockMutex;
import Data.TextBuffer : scr = GetBootTTY;

private extern (C) {
	extern __gshared ubyte KERNEL_STACK_START;
	ulong getRIP();
	void fpuEnable();
	void fpuDisable();
	void cloneHelper();
}

void autoExit() {
	ulong returncode = void;
	asm {
		mov returncode, RAX;
	}
	GetScheduler.Exit(returncode);
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

		//scr.Writeln("SWITCHING!!!!!!");
		ulong storeRBP = void;
		ulong storeRSP = void;
		asm {
			mov storeRBP[RBP], RBP;
			mov storeRSP[RBP], RSP;
		}
		ulong storeRIP = getRIP();
		if (storeRIP == SWITCH_MAGIC) // Swap is done
			return;

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

	alias CloneFunc = ulong function(void*);
	PID Clone(CloneFunc func, VirtAddress stack, void* userdata, string processName) {
		Process* process = new Process();
		if (!stack.Int)
			stack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;

		ulong stackEntries;
		void set(int id, ulong value) {
			*(stack - ulong.sizeof * (id + 1)).Ptr!ulong = value;
			stackEntries++;
		}

		set(0, cast(ulong)&autoExit);
		set(1, cast(ulong)userdata);
		set(2, cast(ulong)func);

		with (process) {
			pid = getFreePid;
			name = processName.dup;

			uid = current.uid;
			gid = current.gid;

			parent = current.pid;

			threadState.rip = VirtAddress(&cloneHelper);
			threadState.rbp = VirtAddress(0);
			threadState.rsp = stack - ulong.sizeof * stackEntries /* Two args */ ;
			threadState.fpuEnabled = current.threadState.fpuEnabled;
			threadState.paging = current.threadState.paging;

			image.stack = stack;

			state = ProcessState.Running;
		}

		processes.Add(process);

		return process.pid;
	}

	void Exit(ulong returncode) {
		current.returnCode = returncode;
		current.state = ProcessState.Exited;

		scr.Writeln(current.name, " is now dead! Returncode: ", cast(void*)returncode);
		//SwitchProcess(false);
		while (true) {
		}
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

		initProcess = new Process();
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
