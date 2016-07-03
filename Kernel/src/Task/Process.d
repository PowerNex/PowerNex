module Task.Process;

import Data.Address;
import Data.LinkedList;
import Memory.Paging;
import Memory.Heap;

extern (C) void switchToUserMode(ulong loc, ulong stack);

alias PID = ulong;

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
	Ready,
	Waiting,
	Exited
}

enum WaitReason {
	Keyboard,
	Timer,
	Join
	//more e.g. harddrive, networking, mutex...
}

struct Process {
	PID pid;
	string name;
	string description;

	ThreadState threadState;
	ImageInformation image;

	ulong uid;
	ulong gid;

	Process* parent;
	LinkedList!Process children;

	ulong returnCode;
	ProcessState state;

	WaitReason wait;
	ulong waitData;

	// MUTEX LOCKS
}
