module task.process;

import data.address;
import data.linkedlist;
import memory.paging;
import memory.heap;
import data.register;
import data.elf;
import fs;
import data.container;
import memory.ref_;
import memory.allocator;

extern (C) void switchToUserMode(ulong loc, ulong stack);

alias PID = ulong;

struct TLS {
	TLS* self;
	ubyte[] startOfTLS;
	Process* process;

	@disable this();

	static TLS* init(Process* process, bool currentData = true) {
		if (currentData && process.parent)
			return init(process, process.parent.threadState.tls.startOfTLS);
		else
			return init(process, process.image.defaultTLS);
	}

	static TLS* init(Process* process, ubyte[] data) {
		VirtAddress addr = process.allocator.allocate(data.length + TLS.sizeof).VirtAddress;
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

	Paging paging;
}

struct ImageInformation {
	VirtAddress userStack;
	VirtAddress kernelStack;
	ubyte[] defaultTLS;
	char*[] arguments;
	Ref!VNode file;
	ELF elf;

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

struct Process {
	~this() {
		if (!pid)
			return;
		import io.log;

		log.info("Freeing: ", name, "(", pid, ")");
		log.printStackTrace();
	}

	PID pid;
	string name;
	string description;

	ulong uid;
	ulong gid;

	ThreadState threadState;
	ImageInformation image;
	bool kernelProcess;
	Registers syscallRegisters;
	Ref!IAllocator allocator;
	Ref!VNode currentDirectory;

	//--TODO: Add pointer to entry in tree, To make it faster to find it children if the scheduler want to switch to a child.
	// Maybe isn't needed because it won't really care unless it needs to find the children.

	//TODO: These should be two types of children, one which share the same memory space (These will have higher priority
	// when the scheduler wants to switch) and one doesn't.
	Ref!Process parent; // Is this even needed to be saved? Only used in two places currently.
	Ref!(Vector!(Ref!Process)) children;

	ProcessState state;
	ulong returnCode; //TODO: Change to ssize_t

	WaitReason wait;
	ulong waitData;

	Ref!(Map!(size_t, Ref!NodeContext)) fileDescriptors;

	size_t fdIDCounter;
}
