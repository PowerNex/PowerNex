module task.scheduler;
import data.address;
import data.color;
import data.linkedlist;
import task.process;
import cpu.gdt;
import cpu.pit;
import task.mutex.spinlockmutex;
import data.textbuffer : scr = getBootTTY;
import memory.heap;
import memory.paging;
import kmain : rootFS;
import io.consolemanager;
import memory.ref_;
import memory.allocator;
import fs;
import data.container;
import io.log;
import memory.allocator.userspaceallocator;

private extern (C) {
	extern __gshared ubyte KERNEL_STACK_START;
	ulong getRIP();
	void fpuEnable();
	void fpuDisable();
	void cloneHelper();
}

extern (C) __gshared Ref!Process _currentProcess;

alias WakeUpFunc = bool function(Process*, void*);

class Scheduler {
public:
	void init() {
		_allProcesses = kernelAllocator.makeRef!(Vector!(Ref!Process))(kernelAllocator);
		_readyProcesses = kernelAllocator.makeRef!(Vector!(Ref!Process))(kernelAllocator);
		_waitingProcesses = kernelAllocator.makeRef!(Vector!(Ref!Process))(kernelAllocator);
		_initIdle(); // PID 0
		_initKernel(); // PID 1
		_pidCounter = 2;
		_currentProcess = _initProcess;
		log.info("PID ", (*_currentProcess).pid, ": Counter ", _currentProcess.counter);
	}

	void switchProcess(bool reschedule = true) {
		if (!_currentProcess)
			return;

		ulong storeRIP = void;
		ulong storeRBP = void;
		ulong storeRSP = void;

		// These will only be stored on the stack
		ulong storeRBX = void;
		ulong storeR12 = void;
		ulong storeR13 = void;
		ulong storeR14 = void;
		ulong storeR15 = void;

		asm nothrow @nogc {
			push RCX; // Save RCX incase D stored someting important there
			mov storeRBP[RBP], RBP;
			mov storeRSP[RBP], RSP;

			mov storeRBX[RBP], RBX;
			mov storeR12[RBP], R12;
			mov storeR13[RBP], R13;
			mov storeR14[RBP], R14;
			mov storeR15[RBP], R15;

			call getRIP;
			mov storeRIP[RBP], RAX;
			mov RCX, _switchMagic;
			cmp RCX, RAX;
			jne noReturn;

			pop RCX;
		}
		return;
		asm nothrow @nogc {
		noReturn:
			mov RBX, storeRBX[RBP];
			mov R12, storeR12[RBP];
			mov R13, storeR13[RBP];
			mov R14, storeR14[RBP];
			mov R15, storeR15[RBP];
			pop RCX;
		}

		with ((*_currentProcess).threadState) {
			rbp = storeRBP;
			rsp = storeRSP;
			rip = storeRIP;
			if (fpuEnabled) {
				ubyte[] storeFPU = fpuStorage;
				asm nothrow @nogc {
					fxsave storeFPU;
				}
				fpuDisable();
			}
		}

		if (reschedule && _currentProcess != _idleProcess) {
			(*_currentProcess).state = ProcessState.ready;
			(*_readyProcesses).put(_currentProcess);
		}

		_doSwitching();
	}

	void waitFor(WaitReason reason, ulong data = 0) {
		(*_currentProcess).state = ProcessState.waiting;
		(*_currentProcess).wait = reason;
		(*_currentProcess).waitData = data;
		(*_waitingProcesses).put(_currentProcess);
		switchProcess(false);
	}

	void wakeUp(WaitReason reason, WakeUpFunc check = &_wakeUpDefault, void* data = cast(void*)0) {
		bool wokeUp = false;

		restartLoop: foreach (i, Ref!Process p; *_waitingProcesses) {
			if ((*p).wait == reason && check(*p, data)) {
				wokeUp = true;
				(*_waitingProcesses).remove(i);
				(*_readyProcesses).put(p);
				goto restartLoop; //XXX:
			}
		}

		if (wokeUp && _currentProcess == _idleProcess)
			switchProcess();
	}

	void uSleep(ulong usecs) {
		if (!usecs)
			usecs = 1;
		waitFor(WaitReason.timer, usecs);
	}

	PID fork() {
		import io.log : log;
		import memory.paging : Paging;

		Ref!Process process = kernelAllocator.makeRef!Process();

		VirtAddress kernelStack = kernelAllocator.allocate(_stackSize).VirtAddress + _stackSize;
		(*process).image.kernelStack = kernelStack;
		(*process).image.defaultTLS = (*_currentProcess).image.defaultTLS;

		void set(T = ulong)(ref VirtAddress stack, T value) {
			auto size = T.sizeof;
			*(stack - size).ptr!T = value;
			stack -= size;
		}

		(*process).syscallRegisters = (*_currentProcess).syscallRegisters;
		(*process).syscallRegisters.rax = 0;

		set(kernelStack, (*process).syscallRegisters);

		with (*process) {
			pid = _getFreePid;
			name = (*_currentProcess).name.dup;

			uid = (*_currentProcess).uid;
			gid = (*_currentProcess).gid;

			parent = _currentProcess;
			children = kernelAllocator.makeRef!(Vector!(Ref!Process))(kernelAllocator);

			Ref!UserSpaceAllocator curAllocator = cast(Ref!UserSpaceAllocator)(*_currentProcess).allocator;
			allocator = cast(Ref!IAllocator)kernelAllocator.makeRef!UserSpaceAllocator(*curAllocator);

			threadState.rip = VirtAddress(&cloneHelper);
			threadState.rbp = kernelStack;
			threadState.rsp = kernelStack;
			threadState.fpuEnabled = (*_currentProcess).threadState.fpuEnabled;
			threadState.paging = new Paging((*_currentProcess).threadState.paging);
			log.warning("New Paging: ", threadState.paging.root(), " Cur Paging: ", (*_currentProcess).threadState.paging.root());
			threadState.tls = TLS.init(*process);

			kernelProcess = (*_currentProcess).kernelProcess;

			currentDirectory = (*_currentProcess).currentDirectory;

			fileDescriptors = kernelAllocator.makeRef!(Map!(size_t, Ref!NodeContext))(kernelAllocator);
			foreach (key, Ref!NodeContext value; *(*_currentProcess).fileDescriptors) {
				log.info("FD: ", key, " name: ", (*value).node.name);
				Ref!NodeContext nc = kernelAllocator.makeRef!NodeContext();
				if ((*value).duplicate(**nc) == IOStatus.success) {
					log.info("success: ", (*nc).node == (*value).node);
					(*fileDescriptors)[key] = nc;
				} else
					log.fatal();
			}

			fdIDCounter = (*_currentProcess).fdIDCounter;

			state = ProcessState.ready;
		}

		(*(*_currentProcess).children).put(process);

		(*_allProcesses).put(process);
		(*_readyProcesses).put(process);

		return (*process).pid;
	}

	alias CloneFunc = ulong function(void*);
	PID clone(CloneFunc func, VirtAddress userStack, void* userdata, string processName) {
		Ref!Process process = kernelAllocator.makeRef!Process();

		log.debug_("userStack: ", userStack);
		if (!userStack.num) // _currentProcess.heap will be new the new process heap
			userStack = (*(*_currentProcess).allocator).allocate(_stackSize).VirtAddress + _stackSize;
		VirtAddress kernelStack = kernelAllocator.allocate(_stackSize).VirtAddress + _stackSize;
		(*process).image.userStack = userStack;
		(*process).image.kernelStack = kernelStack;
		(*process).image.defaultTLS = (*_currentProcess).image.defaultTLS;

		void set(T = ulong)(ref VirtAddress stack, T value) {
			auto size = T.sizeof;
			*(stack - size).ptr!T = value;
			stack -= size;
		}

		with ((*process).syscallRegisters) {
			rbp = userStack;
			rdi = VirtAddress(userdata);
			rax = 0xDEAD_C0DE;
		}

		set(userStack, 0); // Jump to null if it forgot to run exit.

		with ((*process).syscallRegisters) {
			rip = VirtAddress(func);
			cs = (*_currentProcess).syscallRegisters.cs;
			flags = (*_currentProcess).syscallRegisters.flags;
			rsp = userStack;
			ss = (*_currentProcess).syscallRegisters.ss;
		}

		set(kernelStack, (*process).syscallRegisters);

		with (*process) {
			pid = _getFreePid;
			name = processName.dup;

			uid = (*_currentProcess).uid;
			gid = (*_currentProcess).gid;

			parent = _currentProcess;
			children = kernelAllocator.makeRef!(Vector!(Ref!Process))(kernelAllocator);
			allocator = (*_currentProcess).allocator;
			log.fatal("process: ", name, "(", pid, ")\tallocator: ", cast(void*)*allocator);

			threadState.rip = VirtAddress(&cloneHelper);
			threadState.rbp = kernelStack;
			threadState.rsp = kernelStack;
			threadState.fpuEnabled = (*_currentProcess).threadState.fpuEnabled;
			threadState.paging = (*_currentProcess).threadState.paging;
			threadState.paging.refCounter++;
			threadState.tls = TLS.init(*process, false);

			// image.stack is set above

			kernelProcess = (*_currentProcess).kernelProcess;

			currentDirectory = (*_currentProcess).currentDirectory;

			fileDescriptors = kernelAllocator.makeRef!(Map!(size_t, Ref!NodeContext))(kernelAllocator);
			foreach (key, Ref!NodeContext value; *(*_currentProcess).fileDescriptors) {
				log.info("FD: ", key, " name: ", (*value).node.name);
				Ref!NodeContext nc = kernelAllocator.makeRef!NodeContext();
				if ((*value).duplicate(**nc) == IOStatus.success) {
					log.info("success: ", (*nc).node == (*value).node);
					(*fileDescriptors)[key] = nc;
				} else
					log.fatal();
			}
			fdIDCounter = (*_currentProcess).fdIDCounter;

			state = ProcessState.ready;
		}

		(*(*_currentProcess).children).put(process);

		(*_allProcesses).put(process);
		(*_readyProcesses).put(process);

		return (*process).pid;
	}

	ulong join(PID pid = 0) {
		if (!(*_currentProcess).children)
			return 0x1000; //TODO:
		while (true) {
			bool foundit;
			foreach (i, Ref!Process child; *(*_currentProcess).children) {
				if (pid == 0 || (*child).pid == pid) {
					foundit = true;
					if ((*child).state == ProcessState.exited) {
						ulong code = (*child).returnCode;
						(*(*_currentProcess).children).remove(i);
						(*_allProcesses).remove(child);

						with (*child) {
							name.destroy;
							description.destroy;
							//TODO free stack

							//children was destroy'ed when calling Exit
						}
						//child.dispose();
						(*(*_currentProcess).children).remove(i);

						return code;
					}
				}
			}
			if (pid && !foundit)
				return 0x1001; //TODO:

			waitFor(WaitReason.join, pid);
		}
	}

	void exit(ulong returncode) {
		import io.log : log;

		(*_currentProcess).returnCode = returncode;
		(*_currentProcess).state = ProcessState.exited;

		log.info((*_currentProcess).pid, "(", (*_currentProcess).name, ") is now dead! Returncode: ", cast(void*)returncode);

		if (_currentProcess == _initProcess) {
			auto fg = scr.foreground;
			auto bg = scr.background;
			scr.foreground = Color(255, 0, 255);
			scr.background = Color(255, 255, 0);
			scr.writeln("init process exited. No more work to do.");
			scr.foreground = fg;
			scr.background = bg;
			log.fatal("init process exited. No more work to do.");
		}

		(*_currentProcess).fileDescriptors = null;

		foreach (i, Ref!Process child; *(*_currentProcess).children) {
			if ((*child).state == ProcessState.exited) {
				(*child).name.destroy;
				(*child).description.destroy;
				//TODO free stack
			} else {
				//TODO send SIGHUP etc.
				(*(*_initProcess).children).put(child);
			}
		}

		wakeUp(WaitReason.join, cast(WakeUpFunc)&_wakeUpJoin, cast(void*)*_currentProcess);
		switchProcess(false);
		assert(0);
	}

	@property Ref!Process currentProcess() {
		return _currentProcess;
	}

	@property Ref!(Vector!(Ref!Process)) allProcesses() {
		return _allProcesses;
	}

private:
	enum _stackSize = 0x1_0000;
	enum ulong _switchMagic = 0x1111_DEAD_C0DE_1111;

	ulong _pidCounter;
	bool _initialized;
	Ref!(Vector!(Ref!Process)) _allProcesses;
	Ref!(Vector!(Ref!Process)) _readyProcesses;
	Ref!(Vector!(Ref!Process)) _waitingProcesses;

	Ref!Process _idleProcess;
	Ref!Process _initProcess;

	ulong _getFreePid() {
		import io.log : log;

		if (_pidCounter == ulong.max)
			log.fatal("Out of pids!");
		return _pidCounter++;
	}

	static bool _wakeUpDefault(Process* p, void* data) {
		return true;
	}

	static bool _wakeUpJoin(Process* p, Process* child) {
		if (p == (*child.parent) && (p.waitData == 0 || p.waitData == child.pid))
			return true;
		return false;
	}

	static void _idle() {
		asm {
		start:
			sti;
			hlt;
			jmp start;
		}
	}

	void _initIdle() {
		import memory.paging : getKernelPaging;

		VirtAddress userStack = kernelAllocator.allocate(_stackSize).VirtAddress + _stackSize;
		VirtAddress kernelStack = kernelAllocator.allocate(_stackSize).VirtAddress + _stackSize;
		_idleProcess = kernelAllocator.makeRef!Process();

		with ((*_idleProcess).syscallRegisters) {
			rip = VirtAddress(&_idle);
			cs = 0x8;
			flags = 0x202;
			rsp = userStack;
			ss = cs + 8;
		}

		with (*_idleProcess) {
			pid = 0;
			name = "[Idle]";
			description = "Idle thread";

			uid = 0;
			gid = 0;

			children = kernelAllocator.makeRef!(Vector!(Ref!Process))(kernelAllocator);
			import memory.allocator.wrappedallocator : WrappedAllocator;

			allocator = cast(Ref!IAllocator)kernelAllocator.makeRef!WrappedAllocator(kernelAllocator);

			threadState.rip = VirtAddress(&_idle);
			threadState.rbp = userStack;
			threadState.rsp = userStack;
			threadState.fpuEnabled = false;
			threadState.paging = getKernelPaging();
			threadState.paging.refCounter++;
			threadState.tls = TLS.init(*_idleProcess); // image.defaultTLS is empty

			image.userStack = userStack;
			image.kernelStack = kernelStack;

			kernelProcess = true;

			currentDirectory = (*rootFS).root;

			fileDescriptors = kernelAllocator.makeRef!(Map!(size_t, Ref!NodeContext))(kernelAllocator);

			state = ProcessState.ready;
		}
		(*_allProcesses).put(_idleProcess);
	}

	void _initKernel() {
		import memory.paging : getKernelPaging;

		_initProcess = kernelAllocator.makeRef!Process();

		VirtAddress kernelStack = kernelAllocator.allocate(_stackSize).VirtAddress + _stackSize;
		with (_initProcess.data) {
			pid = 1;
			name = "init";
			description = "The init process";
			uid = 0;
			gid = 0;

			threadState.rip = VirtAddress(0);
			threadState.rbp = VirtAddress(0);
			threadState.rsp = VirtAddress(0);
			threadState.fpuEnabled = false;
			threadState.paging = getKernelPaging();
			//threadState.paging.refCounter++; Not needed. "Is" already +1 for this
			threadState.tls = null; // This will be _initialized when the init process is loaded

			image.userStack = VirtAddress(&KERNEL_STACK_START);
			image.kernelStack = kernelStack;

			kernelProcess = false;

			currentDirectory = (*rootFS).root;
			fileDescriptors = kernelAllocator.makeRef!(Map!(size_t, Ref!NodeContext))(kernelAllocator);
			Ref!NodeContext nc = kernelAllocator.makeRef!NodeContext();
			Ref!VNode stdio = (*rootFS).root.findNode("/io/stdio");
			if ((*stdio).open(**nc, FileDescriptorMode.write) == IOStatus.success)
				(*fileDescriptors)[fdIDCounter++] = nc;
			state = ProcessState.running;

			children = kernelAllocator.makeRef!(Vector!(Ref!Process))(kernelAllocator);
			// allocator will be _initialized when the init process is loaded
		}
		(*_allProcesses).put(_initProcess);
	}

	Ref!Process _nextProcess() {
		if ((*_readyProcesses).length) {
			Ref!Process next = (*_readyProcesses)[0];
			(*_readyProcesses).remove(0);
			return next;
		} else
			return _idleProcess;
	}

	void _doSwitching() {
		import cpu.msr;

		_currentProcess = _nextProcess();
		(*_currentProcess).state = ProcessState.running;

		ulong storeRIP = (*_currentProcess).threadState.rip;
		ulong storeRBP = (*_currentProcess).threadState.rbp;
		ulong storeRSP = (*_currentProcess).threadState.rsp;

		(*_currentProcess).threadState.paging.install();

		MSR.fsBase = cast(ulong)(*_currentProcess).threadState.tls;

		GDT.tss.rsp0 = (*_currentProcess).image.kernelStack;

		asm {
			mov RAX, RBP; // RBP will be overritten below

			mov RCX, storeRIP[RAX]; // RCX is the return address
			mov RBP, storeRBP[RAX];
			mov RSP, storeRSP[RAX];
			mov RAX, _switchMagic;
			jmp RCX;
		}
	}
}

//XXX: IsSchedulerInited
__gshared bool isSchedulerInited = false;

Scheduler getScheduler() {
	import data.util : inplaceClass;

	__gshared Scheduler scheduler;
	__gshared ubyte[__traits(classInstanceSize, Scheduler)] data;
	if (!scheduler) {
		scheduler = inplaceClass!Scheduler(data);
		isSchedulerInited = true;
	}
	return scheduler;
}
