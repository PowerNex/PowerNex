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
extern extern (C) void cloneHelper() @trusted;

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

		static ulong spinner(void* pixel_) {
			ubyte* pixel = cast(ubyte*)pixel_;

			ubyte rand = cast(ubyte)pixel;
			ubyte color = cast(ubyte)((rand + (rand & 1) * 3 + (rand % 3 == 0 ? 7 : 2)) % 7);
			const ubyte first = cast(ubyte)(color | color << 4 | 8);
			const ubyte second = cast(ubyte)(color | color << 4 | 8 << 4);

			while (true) {
				*pixel = first;
				asm pure @trusted nothrow @nogc {
					mov RAX, 1; // yield
					//syscall; /// Can't use syscall due to sysret sets CPL=3
					int 0x80;
				}

				*pixel = second;
				asm pure @trusted nothrow @nogc {
					mov RAX, 1; // yield
					//syscall;
					int 0x80;
				}
			}
		}

		static foreach (ubyte x; 0 .. 80) {
			addKernelTask(&_cpuInfo[0], &spinner, (VirtAddress(0xb8000) + (0 * 80 + x) * 2 + 1).ptr);
			addKernelTask(&_cpuInfo[1], &spinner, (VirtAddress(0xb8000) + (24 * 80 + x) * 2 + 1).ptr);
		}

		static foreach (ubyte y; 1 .. 24) {
			addKernelTask(&_cpuInfo[2], &spinner, (VirtAddress(0xb8000) + (y * 80 + 0) * 2 + 1).ptr);
			addKernelTask(&_cpuInfo[3], &spinner, (VirtAddress(0xb8000) + (y * 80 + 79) * 2 + 1).ptr);
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
		import stl.arch.amd64.lapic;

		CPUInfo* cpuInfo = &_cpuInfo[LAPIC.getCurrentID()];
		if (!cpuInfo.enabled)
			return null;
		return cpuInfo.currentThread;
	}

	void doWork(Registers* registers) @trusted {
		import stl.io.vga;
		import stl.arch.amd64.lapic;

		if (!_isEnabled)
			return;

		CPUInfo* cpuInfo = &_cpuInfo[LAPIC.getCurrentID()];
		if (!cpuInfo.enabled)
			return;
		VMThread* thread = cpuInfo.currentThread;
		if (!thread)
			return;

		if (!--(thread.timeSlotsLeft))
			_switchProcess();
	}

	void yield() {
		_switchProcess();
	}

	void addKernelTask(CPUInfo* cpuInfo, KernelTaskFunction func, void* userdata) {
		VMProcess* newProcess = newStruct!VMProcess(getKernelPaging.tableAddress);
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
		set(taskStackPtr, 0x1337_DEAD_C0DE_1337);

		with (newThread.syscallRegisters) {
			rip = VirtAddress(func);
			cs = 0x8;
			flags = 0x202; // Interrupt Enable Flag
			rsp = taskStack.end;
			ss = cs + 0x8;
		}

		set(taskStackPtr, newThread.syscallRegisters);

		with (newThread) {
			process = newProcess;
			state = VMThread.State.active;
			threadState.basePtr = threadState.stackPtr = taskStackPtr;
			threadState.instructionPtr = VirtAddress(&cloneHelper);
			threadState.paging = &newProcess.backend;
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

	__gshared SpinLock _cpuInfoMutex;
	__gshared CPUInfo[maxCPUCount] _cpuInfo;
	__gshared size_t _coresActive;

	//__gshared Vector!(VMThread*) _threads;

	void _switchProcess() @trusted {
		import stl.arch.amd64.lapic;
		import stl.arch.amd64.msr;
		import stl.arch.amd64.gdt;

		CPUInfo* cpuInfo = &_cpuInfo[LAPIC.getCurrentID()];
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
						ubyte[] storeFPU = fpuStorage;
						asm pure @trusted nothrow @nogc {
							fxsave storeFPU;
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

			newThread.threadState.paging.bind();

			MSR.fs = newThread.threadState.tls;

			GDT.setRSP0(cpuInfo.id, cpuInfo.currentThread.kernelStack);

			{
				import syscall;

				SyscallHandler.setKernelStack(cpuInfo);
			}

			asm pure @trusted nothrow @nogc {
				mov RAX, RBP; // RBP will be overritten below

				mov RBX, storeRIP[RAX];
				mov RBP, storeRBP[RAX];
				mov RSP, storeRSP[RAX];
				mov RAX, _switchMagic;
				jmp RBX;
			}
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

		VMProcess* idleProcess = newStruct!VMProcess(getKernelPaging.tableAddress);
		enum stackSize = 0x1000 - BuddyHeader.sizeof;
		ubyte[] taskStack_ = Heap.allocate(stackSize);
		VirtMemoryRange taskStack = VirtMemoryRange(VirtAddress(&taskStack_[0]), VirtAddress(&taskStack_[0]) + stackSize);

		VMThread* idleThread = newStruct!VMThread;
		with (idleThread) {
			process = idleProcess;
			state = VMThread.State.active;
			threadState.basePtr = threadState.stackPtr = taskStack.end;
			threadState.instructionPtr = VirtAddress(&idle);
			threadState.paging = &idleProcess.backend;
			stack = taskStack;
			kernelTask = true;

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
			process = kernelProcess;
			cpuAssigned = 0;
			state = VMThread.State.running;
			threadState.paging = getKernelPaging();
			stack = currentStack;
			kernelTask = false;
		}
		cpuInfo.allThread.put(kernelThread);
	}
}
