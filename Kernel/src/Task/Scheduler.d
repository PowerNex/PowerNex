module Task.Scheduler;
import Data.Address;
import Data.LinkedList;
import Task.Process;
import CPU.GDT;
import CPU.PIT;
import Task.Mutex.SpinLockMutex;
import Data.TextBuffer : scr = GetBootTTY;
import Memory.Heap;
import Memory.Paging;

private extern (C) {
	extern __gshared ubyte KERNEL_STACK_START;
	ulong getRIP();
	void fpuEnable();
	void fpuDisable();
	void cloneHelper();
}

void autoExit() {
	asm {
		naked;
		mov RDI, RAX;
		mov RAX, 0;
		int 0x80;
	}
}

class Scheduler {
public:
	void Init() {
		allProcesses = new LinkedList!Process();
		readyProcesses = new LinkedList!Process();
		waitingProcesses = new LinkedList!Process();
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

		if (reschedule && current != idleProcess) {
			current.state = ProcessState.Ready;
			readyProcesses.Add(current);
		}

		doSwitching();
	}

	void WaitFor(WaitReason reason, ulong data = 0) {
		current.state = ProcessState.Waiting;
		current.wait = reason;
		current.waitData = data;
		waitingProcesses.Add(current);
		SwitchProcess(false);
	}

	alias WakeUpFunc = bool function(Process*, void*);
	void WakeUp(WaitReason reason, WakeUpFunc check = &wakeUpDefault, void* data = cast(void*)0) {
		bool wokeUp = false;

		for (int i = 0; i < waitingProcesses.Length; i++) {
			Process* p = waitingProcesses.Get(i);
			if (p.wait == reason && check(p, data)) {
				wokeUp = true;
				waitingProcesses.Remove(i);
				readyProcesses.Add(p);
			}
		}

		if (wokeUp && current == idleProcess)
			SwitchProcess();
	}

	void USleep(ulong usecs) {
		WaitFor(WaitReason.Timer, usecs);
	}

	PID Fork() {
		import IO.Log : log;
		import Memory.Paging : Paging;

		Process* process = new Process();
		VirtAddress userStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		VirtAddress kernelStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		process.image.userStack = userStack;
		process.image.kernelStack = kernelStack;

		void set(T = ulong)(ref VirtAddress stack, T value) {
			auto size = T.sizeof;
			*(stack - size).Ptr!T = value;
			stack -= size;
		}

		process.syscallRegisters = current.syscallRegisters;

		memcpy((userStack - StackSize).Ptr, (current.image.userStack - StackSize).Ptr, StackSize);

		ulong oldStack = (current.image.userStack - StackSize).Int;
		long stackDiff = (userStack - current.image.userStack).Int;
		log.Debug("UserStack: ", userStack.Ptr, " oldStack: ", current.image.userStack.Ptr, " diff: ", cast(void*)stackDiff);

		void fixStack(ref ulong val) {
			if (oldStack <= val && val <= oldStack + StackSize) {
				log.Debug("Changing: ", cast(void*)val, " to: ", cast(void*)(val + stackDiff));
				val += stackDiff;
			}
		}

		with (process.syscallRegisters) {
			R15 = 0; //fixStack(R15);
			R14 = 0; //fixStack(R14);
			R13 = 0; //fixStack(R13);
			R12 = 0; //fixStack(R12);
			R11 = 0; //fixStack(R11);
			R10 = 0; //fixStack(R10);
			R9 = 0; //fixStack(R9);
			R8 = 0; //fixStack(R8);
			RBP = 0; //fixStack(RBP);
			RDI = 0; //fixStack(RDI);
			RSI = 0; //fixStack(RSI);
			RDX = 0; //fixStack(RDX);
			RCX = 0; //fixStack(RCX);
			RBX = 0; //fixStack(RBX);
			RAX = 0;
			fixStack(RSP);
		}

		set(kernelStack, process.syscallRegisters);

		with (process) {
			pid = getFreePid;
			name = current.name.dup;

			uid = current.uid;
			gid = current.gid;

			parent = current.parent;

			threadState.rip = VirtAddress(&cloneHelper);
			threadState.rbp = kernelStack;
			threadState.rsp = kernelStack;
			threadState.fpuEnabled = current.threadState.fpuEnabled;
			threadState.paging = new Paging(current.threadState.paging);

			kernelProcess = current.kernelProcess;

			state = ProcessState.Ready;

			heap = new Heap(current.heap);
		}

		if (process.parent)
			with (process.parent) {
				if (!children)
					children = new LinkedList!Process;
				children.Add(process);
			}

		allProcesses.Add(process);
		readyProcesses.Add(process);

		log.Warning("New fork'd pid: ", process.pid);

		return process.pid;
	}

	alias CloneFunc = ulong function(void*);
	PID Clone(CloneFunc func, VirtAddress userStack, void* userdata, string processName) {
		Process* process = new Process();
		if (!userStack.Int)
			userStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		VirtAddress kernelStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		process.image.userStack = userStack;
		process.image.kernelStack = kernelStack;

		void set(T = ulong)(ref VirtAddress stack, T value) {
			auto size = T.sizeof;
			*(stack - size).Ptr!T = value;
			stack -= size;
		}

		with (process.syscallRegisters) {
			RBP = userStack;
			RDI = VirtAddress(userdata);
			RAX = 0xDEAD_C0DE;
		}

		set(userStack, cast(ulong)&autoExit);

		with (process.syscallRegisters) {
			RIP = VirtAddress(func);
			CS = current.syscallRegisters.CS;
			Flags = current.syscallRegisters.Flags;
			RSP = userStack;
			SS = current.syscallRegisters.SS;
		}

		set(kernelStack, process.syscallRegisters);

		with (process) {
			pid = getFreePid;
			name = processName.dup;

			uid = current.uid;
			gid = current.gid;

			parent = current;

			threadState.rip = VirtAddress(&cloneHelper);
			threadState.rbp = kernelStack;
			threadState.rsp = kernelStack;
			threadState.fpuEnabled = current.threadState.fpuEnabled;
			threadState.paging = current.threadState.paging;
			threadState.paging.RefCounter++;

			// image.stack is set above

			kernelProcess = current.kernelProcess;

			state = ProcessState.Ready;

			heap = current.heap;
			current.heap.RefCounter++;
		}

		if (process.parent)
			with (process.parent) {
				if (!children)
					children = new LinkedList!Process;
				children.Add(process);
			}

		allProcesses.Add(process);
		readyProcesses.Add(process);

		return process.pid;
	}

	ulong Join(PID pid = 0) {
		while (true) {
			for (int i = 0; i < current.children.Length; i++) {
				Process* child = current.children.Get(i);

				if (child.state == ProcessState.Exited && (pid == 0 || child.pid == pid)) {
					ulong code = child.returnCode;
					current.children.Remove(child);
					allProcesses.Remove(child);

					with (child) {
						name.destroy;
						description.destroy;
						//TODO free stack

						if (children)
							children.destroy;
					}
					child.destroy;

					return code;
				}
			}

			WaitFor(WaitReason.Join, pid);
		}
	}

	void Exit(ulong returncode) {
		import IO.Log : log;

		current.returnCode = returncode;
		current.state = ProcessState.Exited;

		log.Info(current.pid, "(", current.name, ") is now dead! Returncode: ", cast(void*)returncode);

		WakeUp(WaitReason.Join, cast(WakeUpFunc)&wakeUpJoin, cast(void*)current);
		SwitchProcess(false);
		assert(0);
	}

	@property Process* CurrentProcess() {
		return current;
	}

	@property LinkedList!Process AllProcesses() {
		return allProcesses;
	}

private:
	enum StackSize = 0x1000;
	enum ulong SWITCH_MAGIC = 0x1111_DEAD_C0DE_1111;

	ulong pidCounter;
	bool initialized;
	LinkedList!Process allProcesses;
	LinkedList!Process readyProcesses;
	LinkedList!Process waitingProcesses;
	Process* current;

	Process* idleProcess;
	Process* initProcess;

	ulong getFreePid() {
		import IO.Log : log;

		if (pidCounter == ulong.max)
			log.Fatal("Out of pids!");
		return pidCounter++;
	}

	static bool wakeUpDefault(Process* p, void* data) {
		return true;
	}

	static bool wakeUpJoin(Process* p, Process* child) {
		if (p == child.parent && (p.waitData == 0 || p.waitData == child.pid))
			return true;
		return false;
	}

	static void idle() {
		import HW.BGA.BGA : GetBGA;
		import Data.Color;

		auto w = GetBGA.Width;
		//auto h = GetBGA.Height;
		Color color = Color(0x88, 0x53, 0x12);
		asm {
		start:
			sti;
		}
		color.r += 10;
		color.g += 10;
		color.b += 10;
		GetBGA.putRect(w - 10, 0, 10, 10, color);
		asm {
			hlt;
			jmp start;
		}
	}

	void initIdle() {
		import Memory.Paging : GetKernelPaging;

		VirtAddress userStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		VirtAddress kernelStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		idleProcess = new Process();
		with (idleProcess) {
			pid = 0;
			name = "[Idle]";
			description = "Idle thread";
			uid = 0;
			gid = 0;
			threadState.rip = VirtAddress(&idle);
			threadState.rbp = userStack;
			threadState.rsp = userStack;
			threadState.fpuEnabled = false;
			threadState.paging = GetKernelPaging();
			threadState.paging.RefCounter++;

			image.userStack = userStack;
			image.kernelStack = kernelStack;

			kernelProcess = true;

			state = ProcessState.Ready;

			heap = null; // Idle can't allocate any userspace data!
		}
		allProcesses.Add(idleProcess);
	}

	void initKernel() {
		import Memory.Paging : GetKernelPaging;

		initProcess = new Process();

		VirtAddress kernelStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
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
			//threadState.paging.RefCounter++; Not needed. "Is" already +1 for this

			image.userStack = VirtAddress(&KERNEL_STACK_START);
			image.kernelStack = kernelStack;

			kernelProcess = false;

			state = ProcessState.Running;

			heap = null; // This will be initialized when the init process is loaded
		}
		allProcesses.Add(initProcess);
	}

	Process* nextProcess() {
		if (readyProcesses.Length)
			return readyProcesses.Remove(0);
		else
			return idleProcess;
	}

	void doSwitching() {
		current = nextProcess();
		current.state = ProcessState.Running;

		ulong storeRIP = current.threadState.rip;
		ulong storeRBP = current.threadState.rbp;
		ulong storeRSP = current.threadState.rsp;

		current.threadState.paging.Install();
		GDT.tss.RSP0 = current.image.kernelStack;

		asm {
			mov RAX, RBP; // RBP will be overritten below

			mov RBX, storeRIP[RAX];
			mov RBP, storeRBP[RAX];
			mov RSP, storeRSP[RAX];
			mov RAX, SWITCH_MAGIC;
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
