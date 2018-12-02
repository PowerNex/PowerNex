module syscall.action.exit;

import syscall;

@Syscall(0) @SyscallArgument!(size_t) size_t exit(size_t returnValue) {
	assert(0, "TODO: Implement process.exit()!");
}
