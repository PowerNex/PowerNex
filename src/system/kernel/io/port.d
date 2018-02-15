module stl.arch.amd64.ioport;

import stl.trait;

T inp(T)(ushort port) {
	T ret;
	asm pure nothrow {
		mov DX, port;
	}

	static if (isByte!T) {
		asm pure nothrow {
			 in AL, DX;
			mov ret, AL;
		}
	} else static if (isShort!T) {
		asm pure nothrow {
			 in AX, DX;
			mov ret, AX;
		}
	} else static if (isInt!T) {
		asm pure nothrow {
			 in EAX, DX;
			mov ret, EAX;
		}
	} else
		static assert(0);

	return ret;
}

void outp(T)(ushort port, T d) {
	uint data = d;
	asm pure nothrow {
		mov EAX, data;
		mov DX, port;
	}

	static if (isByte!T) {
		asm pure nothrow {
			out DX, AL;
		}
	} else static if (isShort!T) {
		asm pure nothrow {
			out DX, AX;
		}
	} else static if (isInt!T) {
		asm pure nothrow {
			out DX, EAX;
		}
	} else
		static assert(0);
}
