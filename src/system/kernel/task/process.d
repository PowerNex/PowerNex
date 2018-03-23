module task.process;

import stl.address;
import data.linkedlist;
import memory.kheap;
import stl.register;
import data.elf;
import fs;
import data.container;
import memory.ptr;
import memory.allocator;
import memory.vmm;

extern (C) void switchToUserMode(ulong loc, ulong stack);

alias PID = ulong;

struct TLS {
	TLS* self;
	ubyte[] startOfTLS;
	Process* process;

	@disable this();

	static TLS* init(Process* process, bool currentData = true) {
		if (currentData && process.parent)
			return init(process, (*process.parent).threadState.tls.startOfTLS);
		else
			return init(process, process.image.defaultTLS);
	}

	static TLS* init(Process* process, ubyte[] data) {
		VirtAddress addr = (*process.allocator).allocate(data.length + TLS.sizeof).VirtAddress;
		memcpy(addr.ptr, data.ptr, data.length);
		TLS* this_ = (addr + data.length).ptr!TLS;
		this_.self = this_;
		this_.startOfTLS = addr.ptr!ubyte[0 .. data.length];
		this_.process = process;
		return this_;
	}
}

struct ThreadState {
	VirtAddress rbp;
	VirtAddress rsp;
	VirtAddress rip;
	bool fpuEnabled;
	align(16) ubyte[512] fpuStorage;
	TLS* tls;

	//XXX: Paging paging;
}

struct ImageInformation {
	VirtAddress userStack;
	VirtAddress kernelStack;
	ubyte[] defaultTLS;
	char*[] arguments;
	//SharedPtr!VNode file;
	//XXX: ELF elf;

	//TODO: fill in
}

enum ProcessState {
	running,
	ready,
	waiting,
	exited
}

enum WaitReason {
	keyboard,
	timer,
	mutex,
	join //more e.g. harddrive, networking, mutex...
}

enum SignalType {
	noMemory,
	kernelError,
	accessDenied,
	corruptedMemory
}

struct Process {
	@disable this(this);
	~this() {
		if (!pid)
			return;
		import io.log;

		Log.info("Freeing: ", name, "(", pid, ")");
		Log.printStackTrace();
	}

	PID pid;
	string name;
	string description;

	ulong uid;
	ulong gid;

	ThreadState threadState;
	ImageInformation image;
	//SharedPtr!VMProcess vmProcess;
	bool kernelProcess;
	Registers syscallRegisters;
	//SharedPtr!IAllocator allocator;
	//SharedPtr!VNode currentDirectory;

	//--TODO: Add pointer to entry in tree, To make it faster to find it children if the scheduler want to switch to a child.
	// Maybe isn't needed because it won't really care unless it needs to find the children.

	//TODO: These should be two types of children, one which share the same memory space (These will have higher priority
	// when the scheduler wants to switch) and one doesn't.
	//SharedPtr!Process parent; // Is this even needed to be saved? Only used in two places currently.
	//SharedPtr!(Vector!(SharedPtr!Process)) children;

	ProcessState state;
	ulong returnCode; //TODO: Change to ptrdiff_t

	WaitReason wait;
	ulong waitData;

	//SharedPtr!(Map!(size_t, SharedPtr!NodeContext)) fileDescriptors;

	size_t fdIDCounter;

	void signal(SignalType signal, string error) { //TODO: MOVE!
	}
}
