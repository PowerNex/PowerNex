module Task.Process;

import Memory.Paging;
import Memory.Heap;

ulong GetPid() {
	import IO.Log : log;

	__gshared ulong counter = 0;
	if (++counter == ulong.max)
		log.Fatal("Out of pids!");
	return counter;
}

class Process {
public:
	ulong Pid;
	bool FirstTime;
	Paging MemoryMap;
	ulong* KernelStack;

	this(ulong pid, bool firstTime, Paging memoryMap, ulong* kernelStack) {
		this.Pid = pid;
		this.FirstTime = firstTime;
		this.MemoryMap = memoryMap;
		this.KernelStack = kernelStack;
		this.shouldFreeStack = false;
	}

	this(ulong pid, bool firstTime, Paging memoryMap) {
		this(pid, firstTime, memoryMap, cast(ulong*)GetKernelHeap.Alloc(0x1000));
		this.shouldFreeStack = true;
	}

	~this() {
		if (shouldFreeStack)
			GetKernelHeap.Free(KernelStack);
	}

private:
	bool shouldFreeStack;
}

class KernelProcess : Process {
public:
	this(void function() func) {
		super(GetPid, true, GetKernelPaging, null);
		FirstTime = true;
		stack = cast(ulong*)GetKernelHeap.Alloc(0x1000);

		stack[510] = cast(ulong)func;
		KernelStack = &(stack[510]);
	}

	~this() {
		GetKernelHeap.Free(stack);
	}

private:
	ulong* stack;
}
