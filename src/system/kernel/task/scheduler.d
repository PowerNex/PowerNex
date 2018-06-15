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

alias ProcessorID = size_t;

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
	align(64) ubyte[0x1000] kernelStack;
}

@safe struct Scheduler {
public static:
	alias KernelTaskFunction = ulong function(void*) @system;

	void init(VirtMemoryRange kernelStack) @trusted {
		import stl.arch.amd64.lapic : LAPIC;

		() @trusted{ LAPIC.externalTick = cast(LAPIC.ExternalTickFunction)&doWork; }();

		{
			_cpuInfo[0].enabled = true;
			_initIdle(&_cpuInfo[0]);
			_coresActive++;
		}

		_initKernel(&_cpuInfo[0], kernelStack);
		_cpuInfo[0].currentThread = _cpuInfo[0].allThread[0];
		_cpuInfo[0].allThread.remove(0);

		static ulong spinner(ubyte x, ubyte y, ubyte color)(void*) {
			ubyte* pixel = (VirtAddress(0xb8000) + (y * 80 + x) * 2 + 1).ptr!ubyte;
			const ubyte first = color | color << 4 | 8;
			const ubyte second = color | color << 4 | 8 << 4;

			while (true) {
				*pixel = first;
				*pixel = second;
			}
		}

		static foreach (ubyte x; 0 .. 80) {
			addKernelTask(&_cpuInfo[0], &spinner!(x, 0, 1), null);
			addKernelTask(&_cpuInfo[1], &spinner!(x, 24, 2), null);
		}

		static foreach (ubyte y; 1 .. 24) {
			addKernelTask(&_cpuInfo[2], &spinner!(0, y, 4), null);
			addKernelTask(&_cpuInfo[3], &spinner!(79, y, 6), null);
		}
	}

	void addCPUCore(ProcessorID cpuID) @trusted {
		if (cpuID >= _maxCPUCount) {
			Log.warning("Too many CPUs. Trying to activate: ", cpuID, ", max amount is: ", _maxCPUCount);
			return;
		}

		{
			_cpuInfoMutex.lock;
			Log.warning("Activate: ", cpuID);
			_cpuInfo[cpuID].id = cpuID;
			_cpuInfo[cpuID].enabled = true;
			_initIdle(&_cpuInfo[cpuID]);
			_cpuInfo[cpuID].currentThread = _cpuInfo[cpuID].idleThread;
			_coresActive++;
			_cpuInfoMutex.unlock;
		}
	}

	CPUInfo* getCPUInfo(ProcessorID cpuID) @trusted {
		assert(cpuID < _maxCPUCount);
		CPUInfo* info = &_cpuInfo[cpuID];
		if (info.enabled)
			return info;
		return null;
	}

	void doWork(Registers* registers) @trusted {
		// Get a new thread to work on!
		import stl.io.vga;
		import stl.arch.amd64.lapic;

		//VGA.writeln("TICK: ", LAPIC.getCurrentID());
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
		set(taskStackPtr, 0); // Jump to null if it forgot to run exit.

		with (newThread.syscallRegisters) {
			rip = VirtAddress(func);
			cs = 0x8;
			flags = 0x202;
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

private static:
	enum ulong _switchMagic = 0x1111_DEAD_C0DE_1111;
	enum ProcessorID _maxCPUCount = 64; // Same as GDT

	__gshared SpinLock _cpuInfoMutex;
	__gshared CPUInfo[_maxCPUCount] _cpuInfo;
	__gshared size_t _coresActive;

	//__gshared Vector!(VMThread*) _threads;

	void _switchProcess() @trusted {
		import stl.arch.amd64.lapic;
		import stl.arch.amd64.msr;
		import stl.arch.amd64.gdt;

		CPUInfo* cpuInfo = &_cpuInfo[LAPIC.getCurrentID()];
		if (!cpuInfo.enabled)
			return;

		if (!cpuInfo.allThread.length)
			return; // Would have switched to the same thread that is already running

		{ // Saving
			ulong storeRBP = void;
			ulong storeRSP = void;
			asm @trusted nothrow @nogc {
				mov storeRBP[RBP], RBP;
				mov storeRSP[RBP], RSP;
			}

			ulong storeRIP = getRIP();
			if (storeRIP == _switchMagic) // Swap is done
				return;

			with (cpuInfo.currentThread.threadState) {
				basePtr = storeRBP;
				stackPtr = storeRSP;
				instructionPtr = storeRIP;
				if (fpuEnabled) {
					ubyte[] storeFPU = fpuStorage;
					asm {
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

		{ // Loading
			cpuInfo.currentThread = cpuInfo.allThread.length ? cpuInfo.allThread.removeAndGet(0) : cpuInfo.idleThread;
			cpuInfo.currentThread.state = VMThread.State.running;

			ulong storeRBP = cpuInfo.currentThread.threadState.basePtr;
			ulong storeRSP = cpuInfo.currentThread.threadState.stackPtr;
			ulong storeRIP = cpuInfo.currentThread.threadState.instructionPtr;

			cpuInfo.currentThread.threadState.paging.bind();

			MSR.fs = cpuInfo.currentThread.threadState.tls;

			GDT.setRSP0(cpuInfo.id, cpuInfo.kernelStack.ptr.VirtAddress + 0x1000);

			asm {
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
			asm {
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

	void _initKernel(CPUInfo* cpuInfo, VirtMemoryRange kernelStack) @trusted {
		VMProcess* kernelProcess = newStruct!VMProcess(getKernelPaging.tableAddress);

		VMThread* kernelThread = newStruct!VMThread;
		with (kernelThread) {
			process = kernelProcess;
			cpuAssigned = 0;
			state = VMThread.State.running;
			threadState.paging = getKernelPaging();
			stack = kernelStack;

			kernelTask = false;
		}
		cpuInfo.allThread.put(kernelThread);
	}

	void _initSpinner(ubyte x, ubyte y)(CPUInfo* cpuInfo) @trusted {

		VMProcess* spinnerProcess = newStruct!VMProcess(getKernelPaging.tableAddress);
		enum stackSize = 0x1000 - BuddyHeader.sizeof;
		ubyte[] taskStack_ = Heap.allocate(stackSize);
		VirtMemoryRange taskStack = VirtMemoryRange(VirtAddress(&taskStack_[0]), VirtAddress(&taskStack_[0]) + stackSize);
		VMThread* spinnerThread = newStruct!VMThread;
		with (spinnerThread) {
			process = spinnerProcess;
			state = VMThread.State.active;
			threadState.basePtr = threadState.stackPtr = taskStack.end;
			threadState.instructionPtr = VirtAddress(&cloneHelper);
			threadState.paging = &spinnerProcess.backend;
			stack = taskStack;
			kernelTask = true;

			with (syscallRegisters) {
				rip = VirtAddress(&spinner);
				cs = 0x8;
				flags = 0x202;
				rsp = taskStack.end;
				ss = cs + 0x8;
			}
		}

		cpuInfo.allThread.put(spinnerThread);
	}
}
