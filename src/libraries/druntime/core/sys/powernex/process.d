module core.sys.powernex.process;

@safe:

alias PID = size_t;

PID fork() @trusted {
	PID ret = void;
	asm pure @trusted nothrow @nogc {
		mov RAX, 3;
		syscall;
		mov ret, RAX;
	}

	return ret;
}
