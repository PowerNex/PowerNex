module syscall.action.write;

import syscall;

@Syscall(2) @SyscallArgument!(size_t) @SyscallArgument!(string) size_t write(size_t fileID, string msg) {
	import stl.io.vga : VGA;
	import stl.io.log : Log;

	VGA.write(msg);

	Log.info("[", fileID, "] ", msg[0 .. (msg[$ - 1] == '\n') ? $ - 1 : $]);
	return msg.length;
}
