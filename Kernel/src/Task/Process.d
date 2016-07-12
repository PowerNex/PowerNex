module Task.Process;

import Data.Address;
import Data.LinkedList;
import Memory.Paging;
import Memory.Heap;
import Data.Register;

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
	VirtAddress userStack;
	VirtAddress kernelStack;
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

	Process* parent;
	LinkedList!Process children;

	ProcessState state;
	ulong returnCode;

	// MUTEX LOCKS
	WaitReason wait;
	ulong waitData;

}
