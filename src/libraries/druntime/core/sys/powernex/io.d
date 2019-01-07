module core.sys.powernex.io;

@safe:

enum FileID : size_t {
	stdin = 0,
	stdout = 1,
	stderr = 1,
}

size_t write(FileID fileID, const(char[]) msg) @trusted {
	size_t ret = void;
	auto msgPtr = msg.ptr;
	auto msgLength = msg.length;
	asm pure @trusted nothrow @nogc {
		mov RAX, 2;
		mov RDI, fileID;
		mov RSI, msgPtr;
		mov RDX, msgLength;
		syscall;
		mov ret, RAX;
	}

	return ret;
}
