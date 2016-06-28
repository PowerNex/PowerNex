module Task.Process;

import Data.Address;
import Memory.Paging;
import Memory.Heap;

extern (C) void switchToUserMode(ulong loc, ulong stack);

struct ThreadState {
	VirtAddress rbp;
	VirtAddress rsp;
	VirtAddress rip;
	bool fpuEnabled;

	align(16) ubyte[512] fpuStorage;

	Paging paging;
}

struct ImageInformation {
	VirtAddress stack;
	//TODO: fill in
}

enum ProcessState {
	Running,
	Waiting,
	Exited
}

struct Process {
	ulong pid;
	string name;
	string description;

	ThreadState threadState;
	ImageInformation image;

	ulong uid;
	ulong gid;

	ulong returnCode;
	ProcessState state;
	bool active;

	// MUTEX LOCKS
}
