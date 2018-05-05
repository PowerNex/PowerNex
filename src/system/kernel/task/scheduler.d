module task.scheduler;

import stl.vmm.vmm;
import stl.vmm.paging;
import arch.paging;
import stl.vmm.heap;

import stl.vector;
import task.thread;

@safe struct Scheduler {
public static:
	void init() {
		_initIdle();
		_initKernel();
	}

	void doWork() {
		// Get a new thread to work on!
	}

private static:
	/*struct CPUInfo {
		Vector!(VMProcess*) preferred;
		Vector!VMThread allThread, toRun, doTheSleep;
	}*/

	//__gshared Vector!CPUInfo _cpuInfo;

	__gshared Vector!(VMThread*) _threads;

	void _initIdle() @trusted {
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
		ubyte[] stack = Heap.allocate(0x1000 - BuddyHeader.sizeof);

		VMThread* idleThread = newStruct!VMThread;
		with (idleThread) {
			process = idleProcess;
			state = VMThread.State.active;
			saveState.basePtr = saveState.stackPtr = VirtAddress(&stack[0]) + 0x1000 - BuddyHeader.sizeof;
			saveState.instructionPtr = VirtAddress(&idle);
			saveState.paging = &idleProcess.backend;
		}

		_threads.put(idleThread);
	}

	void _initKernel() @trusted {
		VMProcess* kernelProcess = newStruct!VMProcess(getKernelPaging.tableAddress);

		VMThread* kernelThread = newStruct!VMThread;
		with (kernelThread) {
			process = kernelProcess;
			state = VMThread.State.running;
		}
	}
}
