module Task.Process;

import Data.Address;
import Data.LinkedList;
import Memory.Paging;
import Memory.Heap;
import Data.Register;

extern (C) void switchToUserMode(ulong loc, ulong stack);

alias PID = ulong;

struct TLS {
	TLS* self;
	ubyte[] startOfTLS;
	Process* process;

	@disable this();

	static TLS* Init(Process* process, bool currentData = true) {
		if (currentData && process.parent)
			return Init(process, process.parent.threadState.tls.startOfTLS);
		else
			return Init(process, process.image.defaultTLS);
	}

	static TLS* Init(Process* process, ubyte[] data) {
		VirtAddress addr = VirtAddress(process.heap.Alloc(data.length + TLS.sizeof));
		memcpy(addr.Ptr, data.ptr, data.length);
		TLS* this_ = (addr + data.length).Ptr!TLS;
		this_.self = this_;
		this_.startOfTLS = addr.Ptr!ubyte[0 .. data.length];
		this_.process = process;
		return this_;
	}

	void Free() {
		process.heap.Free(startOfTLS.ptr);
	}
}

struct ThreadState {
	VirtAddress rbp;
	VirtAddress rsp;
	VirtAddress rip;
	bool fpuEnabled;
	align(16) ubyte[512] fpuStorage;
	TLS* tls;

	Paging paging;
}

struct ImageInformation {
	VirtAddress userStack;
	VirtAddress kernelStack;
	ubyte[] defaultTLS;
	//TODO: fill in
}

enum ProcessState {
	Running,
	Ready,
	Waiting,
	Exited
}

enum WaitReason {
	Keyboard,
	Timer,
	Join //more e.g. harddrive, networking, mutex...
}

struct Process {
	PID pid;
	string name;
	string description;

	ulong uid;
	ulong gid;

	ThreadState threadState;
	ImageInformation image;
	bool kernelProcess;
	Registers syscallRegisters;
	Heap heap;

	Process* parent;
	LinkedList!Process children;

	ProcessState state;
	ulong returnCode;

	// MUTEX LOCKS
	WaitReason wait;
	ulong waitData;
}
