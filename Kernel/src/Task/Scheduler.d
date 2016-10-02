module Task.Scheduler;
import Data.Address;
import Data.Color;
import Data.LinkedList;
import Task.Process;
import CPU.GDT;
import CPU.PIT;
import Task.Mutex.SpinLockMutex;
import Data.TextBuffer : scr = GetBootTTY;
import Memory.Heap;
import Memory.Paging;
import KMain : rootFS;
import IO.ConsoleManager;

private extern (C) {
	extern __gshared ubyte KERNEL_STACK_START;
	ulong getRIP();
	void fpuEnable();
	void fpuDisable();
	void cloneHelper();
}

extern (C) __gshared Process* currentProcess;

class Scheduler {
public:
	void Init() {
		allProcesses = new LinkedList!Process();
		readyProcesses = new LinkedList!Process();
		waitingProcesses = new LinkedList!Process();
		initIdle(); // PID 0
		initKernel(); // PID 1
		pidCounter = 2;
		currentProcess = initProcess;
	}

	void SwitchProcess(bool reschedule = true) {
		if (!currentProcess)
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

		with (currentProcess.threadState) {
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

		if (reschedule && currentProcess != idleProcess) {
			currentProcess.state = ProcessState.Ready;
			readyProcesses.Add(currentProcess);
		}

		doSwitching();
	}

	void WaitFor(WaitReason reason, ulong data = 0) {
		currentProcess.state = ProcessState.Waiting;
		currentProcess.wait = reason;
		currentProcess.waitData = data;
		waitingProcesses.Add(currentProcess);
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

		if (wokeUp && currentProcess == idleProcess)
			SwitchProcess();
	}

	void USleep(ulong usecs) {
		if (!usecs)
			usecs = 1;
		WaitFor(WaitReason.Timer, usecs);
	}

	PID Fork() {
		import IO.Log : log;
		import Memory.Paging : Paging;

		Process* process = new Process();
		VirtAddress kernelStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		process.image.kernelStack = kernelStack;
		process.image.defaultTLS = currentProcess.image.defaultTLS;

		void set(T = ulong)(ref VirtAddress stack, T value) {
			auto size = T.sizeof;
			*(stack - size).Ptr!T = value;
			stack -= size;
		}

		process.syscallRegisters = currentProcess.syscallRegisters;
		process.syscallRegisters.RAX = 0;

		set(kernelStack, process.syscallRegisters);

		with (process) {
			pid = getFreePid;
			name = currentProcess.name.dup;

			uid = currentProcess.uid;
			gid = currentProcess.gid;

			parent = currentProcess;
			heap = new Heap(currentProcess.heap);

			threadState.rip = VirtAddress(&cloneHelper);
			threadState.rbp = kernelStack;
			threadState.rsp = kernelStack;
			threadState.fpuEnabled = currentProcess.threadState.fpuEnabled;
			threadState.paging = new Paging(currentProcess.threadState.paging);
			threadState.tls = TLS.Init(process);

			kernelProcess = currentProcess.kernelProcess;

			currentDirectory = currentProcess.currentDirectory;

			fileDescriptors = new LinkedList!FileDescriptor;
			for (size_t i = 0; i < currentProcess.fileDescriptors.Length; i++)
				fileDescriptors.Add(new FileDescriptor(currentProcess.fileDescriptors.Get(i)));
			fdCounter = currentProcess.fdCounter;

			state = ProcessState.Ready;
		}

		with (currentProcess) {
			if (!children)
				children = new LinkedList!Process;
			children.Add(process);
		}

		allProcesses.Add(process);
		readyProcesses.Add(process);

		return process.pid;
	}

	alias CloneFunc = ulong function(void*);
	PID Clone(CloneFunc func, VirtAddress userStack, void* userdata, string processName) {
		Process* process = new Process();
		import IO.Log;

		log.Debug("userStack: ", userStack);
		if (!userStack.Int) // currentProcess.heap will be new the new process heap
			userStack = VirtAddress(currentProcess.heap.Alloc(StackSize)) + StackSize;
		VirtAddress kernelStack = VirtAddress(new ubyte[StackSize].ptr) + StackSize;
		process.image.userStack = userStack;
		process.image.kernelStack = kernelStack;
		process.image.defaultTLS = currentProcess.image.defaultTLS;

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

		set(userStack, 0); // Jump to null if it forgot to run exit.

		with (process.syscallRegisters) {
			RIP = VirtAddress(func);
			CS = currentProcess.syscallRegisters.CS;
			Flags = currentProcess.syscallRegisters.Flags;
			RSP = userStack;
			SS = currentProcess.syscallRegisters.SS;
		}

		set(kernelStack, process.syscallRegisters);

		with (process) {
			pid = getFreePid;
			name = processName.dup;

			uid = currentProcess.uid;
			gid = currentProcess.gid;

			parent = currentProcess;
			heap = currentProcess.heap;
			currentProcess.heap.RefCounter++;

			threadState.rip = VirtAddress(&cloneHelper);
			threadState.rbp = kernelStack;
			threadState.rsp = kernelStack;
			threadState.fpuEnabled = currentProcess.threadState.fpuEnabled;
			threadState.paging = currentProcess.threadState.paging;
			threadState.paging.RefCounter++;
			threadState.tls = TLS.Init(process, false);

			// image.stack is set above

			kernelProcess = currentProcess.kernelProcess;

			currentDirectory = currentProcess.currentDirectory;

			fileDescriptors = new LinkedList!FileDescriptor;
			for (size_t i = 0; i < currentProcess.fileDescriptors.Length; i++)
				fileDescriptors.Add(new FileDescriptor(currentProcess.fileDescriptors.Get(i)));
			fdCounter = currentProcess.fdCounter;

			state = ProcessState.Ready;
		}

		with (currentProcess) {
			if (!children)
				children = new LinkedList!Process;
			children.Add(process);
		}

		allProcesses.Add(process);
		readyProcesses.Add(process);

		return process.pid;
	}

	ulong Join(PID pid = 0) {
		if (!currentProcess.children)
			return 0x1000;
		while (true) {
			bool foundit;
			for (int i = 0; i < currentProcess.children.Length; i++) {
				Process* child = currentProcess.children.Get(i);

				if (pid == 0 || child.pid == pid) {
					foundit = true;
					if (child.state == ProcessState.Exited) {
						ulong code = child.returnCode;
						currentProcess.children.Remove(child);
						allProcesses.Remove(child);

						with (child) {
							name.destroy;
							description.destroy;
							//TODO free stack

							//children was destroy'ed when calling Exit
						}
						child.destroy;

						return code;
					}
				}
			}
			if (pid && !foundit)
				return 0x1001;

			WaitFor(WaitReason.Join, pid);
		}
	}

	void Exit(ulong returncode) {
		import IO.Log : log;

		currentProcess.returnCode = returncode;
		currentProcess.state = ProcessState.Exited;

		log.Info(currentProcess.pid, "(", currentProcess.name, ") is now dead! Returncode: ", cast(void*)returncode);

		if (currentProcess == initProcess) {
			auto fg = scr.Foreground;
			auto bg = scr.Background;
			scr.Foreground = Color(255, 0, 255);
			scr.Background = Color(255, 255, 0);
			scr.Writeln("Init process exited. No more work to do.");
			scr.Foreground = fg;
			scr.Background = bg;
			log.Fatal("Init process exited. No more work to do.");
		}

		for (size_t i = 0; i < currentProcess.fileDescriptors.Length; i++) {
			FileDescriptor* fd = currentProcess.fileDescriptors.Get(i);
			fd.node.Close();
			fd.destroy;
		}

		if (currentProcess.children) {
			for (int i = 0; i < currentProcess.children.Length; i++) {
				Process* child = currentProcess.children[i];

				if (child.state == ProcessState.Exited) {
					child.name.destroy;
					child.description.destroy;
					//TODO free stack

					child.destroy;
				} else {
					//TODO send SIGHUP etc.
					initProcess.children.Add(child);
				}
			}
			currentProcess.children.destroy;
		}

		WakeUp(WaitReason.Join, cast(WakeUpFunc)&wakeUpJoin, cast(void*)currentProcess);
		SwitchProcess(false);
		assert(0);
	}

	@property Process* CurrentProcess() {
		return currentProcess;
	}

	@property LinkedList!Process AllProcesses() {
		return allProcesses;
	}

private:
	enum StackSize = 0x1_0000;
	enum ulong SWITCH_MAGIC = 0x1111_DEAD_C0DE_1111;

	ulong pidCounter;
	bool initialized;
	LinkedList!Process allProcesses;
	LinkedList!Process readyProcesses;
	LinkedList!Process waitingProcesses;

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

		with (idleProcess.syscallRegisters) {
			RIP = VirtAddress(&idle);
			CS = 0x8;
			Flags = 0x202;
			RSP = userStack;
			SS = CS + 8;
		}

		with (idleProcess) {
			pid = 0;
			name = "[Idle]";
			description = "Idle thread";

			uid = 0;
			gid = 0;

			heap = GetKernelHeap;
			heap.RefCounter++;

			threadState.rip = VirtAddress(&idle);
			threadState.rbp = userStack;
			threadState.rsp = userStack;
			threadState.fpuEnabled = false;
			threadState.paging = GetKernelPaging();
			threadState.paging.RefCounter++;
			threadState.tls = TLS.Init(idleProcess); // image.defaultTLS is empty

			image.userStack = userStack;
			image.kernelStack = kernelStack;

			kernelProcess = true;

			currentDirectory = rootFS.Root;

			fileDescriptors = new LinkedList!FileDescriptor;

			state = ProcessState.Ready;
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
			threadState.tls = null; // This will be initialized when the init process is loaded

			image.userStack = VirtAddress(&KERNEL_STACK_START);
			image.kernelStack = kernelStack;

			kernelProcess = false;

			currentDirectory = rootFS.Root;
			fileDescriptors = new LinkedList!FileDescriptor;
			fileDescriptors.Add(new FileDescriptor(fdCounter++, GetConsoleManager.VirtualConsoles[0]));

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
		import CPU.MSR;

		currentProcess = nextProcess();
		currentProcess.state = ProcessState.Running;

		ulong storeRIP = currentProcess.threadState.rip;
		ulong storeRBP = currentProcess.threadState.rbp;
		ulong storeRSP = currentProcess.threadState.rsp;

		currentProcess.threadState.paging.Install();

		MSR.FSBase = cast(ulong)currentProcess.threadState.tls;

		GDT.tss.RSP0 = currentProcess.image.kernelStack;

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
