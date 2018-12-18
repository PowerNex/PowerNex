module core.sys.powernex.io;

enum StdFile : size_t {
	stdout,
	stderr,
	stdin
}

size_t write(StdFile fileID, string msg) {
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
