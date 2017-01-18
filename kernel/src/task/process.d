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
		VirtAddress addr = VirtAddress(process.heap.alloc(data.length + TLS.sizeof));
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
	Ref!VNode currentDirectory;

	Process* parent;
	LinkedList!Process children;

	ProcessState state;
	ulong returnCode;

	WaitReason wait;
	ulong waitData;

	Ref!(Map!(size_t, Ref!NodeContext)) fileDescriptors;

	size_t fdIDCounter;
}
