module System.Syscall;

import Data.Address;

enum SyscallCategory {
	File,
	Memory,
	Task,
	HW
}

struct SyscallEntry {
	ulong id;
	string name;
	string description;
	SyscallCategory category;
}

@SyscallEntry(0, "Exit", "This terminates the current running process")
ulong Exit(ulong errorcode) {
	import Task.Scheduler : GetScheduler;

	GetScheduler.Exit(errorcode);
	return 0;
}

@SyscallEntry(1, "Clone", "Start a new process")
ulong Clone(ulong function(void*) func, VirtAddress stack, void* userdata, string* name) {
	import Task.Scheduler : GetScheduler;

	return GetScheduler.Clone(func, stack, userdata, *name);
}
