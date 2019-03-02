module task.scheduler;

import stl.vmm.vmm;
import stl.vmm.paging;
import arch.paging;
import stl.vmm.heap;

import stl.vector;
import task.thread;
import stl.spinlock;
import stl.register;
import stl.address;
import stl.io.log : Log;

private import stl.arch.amd64.gdt : maxCPUCount_ = maxCPUCount;

alias ProcessorID = size_t;
enum ProcessorID maxCPUCount = maxCPUCount_;

extern extern (C) ulong getRIP() @trusted;
extern extern (C) void fpuEnable() @trusted;
extern extern (C) void fpuDisable() @trusted;
extern extern (C) void cloneHelperKernelTask() @trusted;
extern extern (C) void cloneHelperFork() @trusted;

@safe struct CPUInfo {
	size_t id;
	bool enabled = false;
	VMThread* currentThread;
	VMThread* idleThread;
	//Vector!(VMProcess*) preferred;
	Vector!(VMThread*) allThread /*, toRun, doTheSleep*/ ;
}

@safe struct Scheduler {
public static:
	alias KernelTaskFunction = ulong function(void*) @system;

	void init(VirtMemoryRange kernelStack) @trusted {
		import stl.arch.amd64.lapic : LAPIC;

		() @trusted { LAPIC.externalTick = cast(LAPIC.ExternalTickFunction)&doWork; }();

		{
			_cpuInfo[0].enabled = true;
			_initIdle(&_cpuInfo[0]);
			_coresActive++;
		}

		_initKernel(&_cpuInfo[0], kernelStack);
		_cpuInfo[0].currentThread = _cpuInfo[0].allThread[0];
		_cpuInfo[0].currentThread.niceFactor = 2;
		_cpuInfo[0].allThread.remove(0);

		import stl.io.vga : CGASlotColor, CGAColor, CGAVideoSlot;

		static ulong spinner(void* pixel_) {
			CGAVideoSlot* pixel = cast(CGAVideoSlot*)pixel_;
			ubyte rand = cast(ubyte)pixel;
			CGAColor color = cast(CGAColor)((rand + (rand & 1) * 3 + (rand % 3 == 0 ? 7 : 2)) % 7);

			const CGASlotColor first = CGASlotColor(color, cast(CGAColor)(color | 8));
			const CGASlotColor second = CGASlotColor(cast(CGAColor)(color | 8), color);

			while (true) {
				pixel.color = first;
				asm pure @trusted nothrow @nogc {
					mov RAX, 1; // yield
					//syscall; /// Can't use syscall due to sysret sets CPL=3
					int 0x80;
				}

				pixel.color = second;
				asm pure @trusted nothrow @nogc {
					mov RAX, 1; // yield
					//syscall;
					int 0x80;
				}
			}
		}

		static foreach (ubyte x; 0 .. 80) {
			addKernelTask("CPU 0 - Spinner", &_cpuInfo[0], &spinner, (VirtAddress(0xb8000) + (0 * 80 + x) * 2).ptr);
			addKernelTask("CPU 1 - Spinner", &_cpuInfo[1], &spinner, (VirtAddress(0xb8000) + (24 * 80 + x) * 2).ptr);
		}

		static foreach (ubyte y; 1 .. 24) {
			addKernelTask("CPU 2 - Spinner", &_cpuInfo[2], &spinner, (VirtAddress(0xb8000) + (y * 80 + 0) * 2).ptr);
			addKernelTask("CPU 3 - Spinner", &_cpuInfo[3], &spinner, (VirtAddress(0xb8000) + (y * 80 + 79) * 2).ptr);
		}
	}

	void addCPUCore(ProcessorID cpuID) @trusted {
		if (cpuID >= maxCPUCount) {
			Log.warning("Too many CPUs. Trying to activate: ", cpuID, ", max amount is: ", maxCPUCount);
			return;
		}

		{
			_cpuInfoMutex.lock;
			Log.warning("Activate: ", cpuID);
			_cpuInfo[cpuID].id = cpuID;
			_cpuInfo[cpuID].enabled = true;
			_initIdle(&_cpuInfo[cpuID]);
			_coresActive++;
			_cpuInfoMutex.unlock;
		}
	}

	CPUInfo* getCPUInfo(ProcessorID cpuID) @trusted {
		assert(cpuID < maxCPUCount);
		CPUInfo* info = &_cpuInfo[cpuID];
		if (info.enabled)
			return info;
		return null;
	}

	VMThread* getCurrentThread() @trusted {
		import stl.arch.amd64.cpu;

		CPUInfo* cpuInfo = &_cpuInfo[getCoreID()];
		if (!cpuInfo.enabled)
			return null;
		return cpuInfo.currentThread;
	}

	void doWork(Registers* registers) @trusted {
		import stl.io.vga;
		import stl.arch.amd64.cpu;
		import stl.arch.amd64.lapic;

		scope (exit)
			LAPIC.setTimerToTrigger(4000);

		if (!_isEnabled)
			return;

		CPUInfo* cpuInfo = &_cpuInfo[getCoreID()];
		if (!cpuInfo.enabled)
			return;
		VMThread* thread = cpuInfo.currentThread;
		if (!thread)
			return;

		if (!--(thread.timeSlotsLeft))
			_switchProcess();
	}

	void yield() {
		import stl.arch.amd64.lapic;

		scope (exit)
			LAPIC.setTimerToTrigger(4000);
		_switchProcess();
	}

	void addKernelTask(string threadName, CPUInfo* cpuInfo, KernelTaskFunction func, void* userdata) {
		VMProcess* newProcess = newStruct!VMProcess(PhysAddress());
		enum stackSize = 0x1000 - BuddyHeader.sizeof;
		ubyte[] taskStack_ = Heap.allocate(stackSize);
		VirtMemoryRange taskStack = VirtMemoryRange(VirtAddress(&taskStack_[0]), VirtAddress(&taskStack_[0]) + stackSize);
		VMThread* newThread = newStruct!VMThread;

		void set(T = ulong)(ref VirtAddress stack, T value) {
			auto size = T.sizeof;
			*(stack - size).ptr!T = value;
			stack -= size;
		}

		VirtAddress taskStackPtr = taskStack.end;

		with (newThread.syscallRegisters) {
			rbp = taskStackPtr;
			rdi = VirtAddress(userdata);
			rax = 0xDEAD_C0DE;
		}

		// TODO: Change this to a magic value, to know if the thread wanted to exit instead of just jumping to null?
		// Probably not a good idea as it is a bug, but idk.
		set(taskStackPtr, 0); // Jump to null if it forgot to run exit.
		set(taskStackPtr, _switchMagic);

		with (newThread.syscallRegisters) {
			rip = VirtAddress(func);
			cs = 0x8;
			flags = 0x202; // Interrupt Enable Flag
			rsp = taskStack.end;
			ss = cs + 0x8;
		}

		set(taskStackPtr, newThread.syscallRegisters);

		with (newThread) {
			pid = _getNextPid();
			name = threadName;
			process = newProcess;
			cpuAssigned = cpuInfo.id;
			state = VMThread.State.active;
			threadState.basePtr = threadState.stackPtr = taskStackPtr;
			threadState.instructionPtr = VirtAddress(&cloneHelperKernelTask);
			stack = taskStack;
			kernelTask = true;
		}

		cpuInfo.allThread.put(newThread);
	}

	@property size_t coresActive() @trusted {
		return _coresActive;
	}

	@property SpinLock* cpuInfoMutex() @trusted {
		return &_cpuInfoMutex;
	}

	@property ref bool isEnabled() @trusted {
		return _isEnabled;
	}

private static:
	enum ulong _switchMagic = 0x1337_DEAD_C0DE_1337;

	__gshared bool _isEnabled;

	__gshared size_t _pidCounter;
	__gshared SpinLock _pidCounterMutex;
	__gshared SpinLock _cpuInfoMutex;
	__gshared CPUInfo[maxCPUCount] _cpuInfo;
	__gshared size_t _coresActive;

	//__gshared Vector!(VMThread*) _threads;

	size_t _getNextPid() @trusted {
		_pidCounterMutex.lock();
		scope (exit)
			_pidCounterMutex.unlock;
		return ++_pidCounter;
	}

	void _switchProcess() @trusted {
		import stl.arch.amd64.cpu;
		import stl.arch.amd64.msr;
		import stl.arch.amd64.gdt;

		CPUInfo* cpuInfo = &_cpuInfo[getCoreID()];
		if (!cpuInfo.enabled)
			Log.fatal("CPU core is not enabled!");

		if (!cpuInfo.allThread.length && cpuInfo.currentThread)
			return; // Would have switched to the same thread that is already running

		{ // Saving
			ulong storeRBP = void;
			ulong storeRSP = void;
			asm pure @trusted nothrow @nogc {
				mov storeRBP[RBP], RBP;
				mov storeRSP[RBP], RSP;
			}

			ulong storeRIP = getRIP();
			if (storeRIP == _switchMagic) // Swap is done
				return;
			// This will only be false the first time it is called!
			if (cpuInfo.currentThread) {
				with (cpuInfo.currentThread.threadState) {
					basePtr = storeRBP;
					stackPtr = storeRSP;
					instructionPtr = storeRIP;
					if (fpuEnabled) {
						ubyte* storeFPU = fpuStorage.ptr;

						asm pure @trusted nothrow @nogc {
							mov RAX, storeFPU;
							fxsave [RAX];
						}

						fpuDisable();
					}
				}

				if (cpuInfo.currentThread != cpuInfo.idleThread) {
					cpuInfo.currentThread.state = VMThread.State.active;
					cpuInfo.allThread.put(cpuInfo.currentThread);
				}
			}
		}
		{ // Loading
			VMThread* newThread = cpuInfo.currentThread = cpuInfo.allThread.length ? cpuInfo.allThread.removeAndGet(0) : cpuInfo.idleThread;
			newThread.state = VMThread.State.running;
			newThread.timeSlotsLeft = newThread.niceFactor;

			ulong storeRBP = newThread.threadState.basePtr;
			ulong storeRSP = newThread.threadState.stackPtr;
			ulong storeRIP = newThread.threadState.instructionPtr;

			newThread.process.bind();

			MSR.fs = newThread.threadState.tls.VirtAddress;

			GDT.setRSP0(cpuInfo.id, cpuInfo.currentThread.kernelStack);

			{
				import syscall;

				SyscallHandler.setKernelStack(cpuInfo);
			}

			Log.setUserspaceSymbolMap(newThread.name, newThread.image.symbols, newThread.image.symbolStrings);

			asm pure @trusted nothrow @nogc {
				mov RAX, RBP; // RBP will be overritten below

				mov RBX, storeRIP[RAX];
				mov RBP, storeRBP[RAX];
				mov RSP, storeRSP[RAX];
				mov RAX, _switchMagic;
				jmp RBX;
			}
			assert(0);
		}
	}

	void _initIdle(CPUInfo* cpuInfo) @trusted {
		extern (C) static void idle() {
			asm pure @trusted nothrow @nogc {
				naked;
			start:
				sti;
				hlt;
				jmp start;
			}
		}

		VMProcess* idleProcess = newStruct!VMProcess(PhysAddress());
		enum stackSize = 0x1000 - BuddyHeader.sizeof;
		ubyte[] taskStack_ = Heap.allocate(stackSize);
		VirtMemoryRange taskStack = VirtMemoryRange(VirtAddress(&taskStack_[0]), VirtAddress(&taskStack_[0]) + stackSize);

		VMThread* idleThread = newStruct!VMThread;
		with (idleThread) {
			pid = _getNextPid();
			name = "Idle Thread";
			process = idleProcess;
			state = VMThread.State.active;
			threadState.basePtr = threadState.stackPtr = taskStack.end;
			threadState.instructionPtr = VirtAddress(&idle);
			stack = taskStack;
			kernelTask = true;
			cpuAssigned = cpuInfo.id;

			with (syscallRegisters) {
				rip = VirtAddress(&idle);
				cs = 0x8;
				flags = 0x202;
				rsp = taskStack.end;
				ss = cs + 0x8;
			}
		}

		cpuInfo.idleThread = idleThread;
	}

	void _initKernel(CPUInfo* cpuInfo, VirtMemoryRange currentStack) @trusted {
		VMProcess* kernelProcess = newStruct!VMProcess(getKernelPaging.tableAddress);

		VMThread* kernelThread = newStruct!VMThread;
		with (kernelThread) {
			pid = _getNextPid();
			name = "Kernel Thread";
			process = kernelProcess;
			cpuAssigned = 0;
			state = VMThread.State.running;
			stack = currentStack;
			kernelTask = false;
		}
		cpuInfo.allThread.put(kernelThread);
	}
}
