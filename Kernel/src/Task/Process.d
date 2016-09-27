module Task.Process;

import Data.Address;
import Data.LinkedList;
import Memory.Paging;
import Memory.Heap;
import Data.Register;
import IO.FS.FileNode;
import IO.FS.DirectoryNode;
import Data.ELF;

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
	FileNode file;
	ELF elf;

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

struct FileDescriptor {
	size_t id;
	FileNode node;
	this(FileDescriptor* fd) {
		this.id = fd.id;
		this.node = fd.node;
		node.Open();
	}

	this(size_t id, FileNode node) {
		this.id = id;
		this.node = node;
		node.Open();
	}
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
	DirectoryNode currentDirectory;

	Process* parent;
	LinkedList!Process children;

	ProcessState state;
	ulong returnCode;

	WaitReason wait;
	ulong waitData;

	LinkedList!FileDescriptor fileDescriptors;
	size_t fdCounter;
}
