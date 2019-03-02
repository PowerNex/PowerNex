module syscall.action.write;

import syscall;

@Syscall(2) @SyscallArgument!(size_t) @SyscallArgument!(string) size_t write(size_t fileID, string msg) {
	import stl.io.vga : VGA;
	import stl.io.log : Log;

	import task.scheduler;
	import task.thread;

	VMThread* thread = Scheduler.getCurrentThread();

	VGA.write(msg);

	if (thread)
		Log.info("[", fileID, "][pid:", thread.pid, "][name:", thread.name, "] ", msg[0 .. (msg[$ - 1] == '\n') ? $ - 1 : $]);
	else
		Log.info("[", fileID, "] ", msg[0 .. (msg[$ - 1] == '\n') ? $ - 1 : $]);
	return msg.length;
}
