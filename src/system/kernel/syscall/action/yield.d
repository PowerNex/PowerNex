module syscall.action.yield;

import syscall;

import stl.io.log;
import task.scheduler;
import task.thread;

@Syscall(1) size_t yield() {
	Scheduler.yield();
	return 0;
}
