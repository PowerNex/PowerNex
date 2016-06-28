module System.Syscall;

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

@SyscallEntry(1, "Yield", "Yield the current process")
ulong Yield() {
	import Task.Scheduler : GetScheduler;

	GetScheduler.SwitchProcess();
	return 0;
}
