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

@SyscallEntry(2, "Log Out")
ulong Log(immutable(char)* str, ulong length, immutable(char)* str2, ulong length2) {
	import IO.Log;

	log.Info(str[0 .. length], str2[0 .. length2]);
	return 0;
}
