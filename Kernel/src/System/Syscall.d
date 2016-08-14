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

@SyscallEntry(2, "Fork", "Start a new process")
ulong Fork() {
	import Task.Scheduler : GetScheduler;
	import IO.Log : log;

	log.Debug("Calling fork!");
	auto pid = GetScheduler.Fork();
	log.Debug("Called fork!: ", pid);
	return pid;
}

@SyscallEntry(3, "Log")
ulong Log(string* str, string* str2) {
	import IO.Log : log;

	if (!str2)
		log.Info(*str);
	else
		log.Info(*str, *str2);
	return 0;
}

@SyscallEntry(4, "Exec", "Replace current process with executable")
ulong Exec(string* file, string[]* args) {
	import IO.Log : log;

	log.Warning("Called Exec: ", *file);

	while (true) {
	}
	return 0xDEAD_C0DE;
}

@SyscallEntry(5, "Alloc", "Allocate memory")
ulong Alloc(ulong size) {
	import Task.Scheduler : GetScheduler;
	return cast(ulong)GetScheduler().CurrentProcess.heap.Alloc(size);
}

@SyscallEntry(6, "Free", "Free memory")
ulong Free(void* addr) {
	import Task.Scheduler : GetScheduler;
	GetScheduler().CurrentProcess.heap.Free(addr);
	return 0;
}

@SyscallEntry(16, "PrintCStr", "Free memory")
ulong PrintCStr(char* str) {
	import Data.String : fromStringz;
	import Data.TextBuffer : scr = GetBootTTY;
	scr.Writeln(str.fromStringz);
	return 0;
}
