module syscall.action.fork;

import syscall;
import task.scheduler;

@Syscall(3) size_t fork() {
	return Scheduler.fork();
}
