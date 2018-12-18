module syscall.action.exit;

import syscall;
import task.scheduler;

@Syscall(0) @SyscallArgument!(size_t) size_t exit(size_t returnValue) {
	while (true)
		Scheduler.yield();

	assert(0, "TODO: Implement process.exit()!");
}
