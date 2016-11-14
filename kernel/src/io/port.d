module IO.Port;

import Data.Util;

T In(T = ubyte)(ushort port) {
	T ret;
	asm {
		mov DX, port;
	}

	static if (isByte!T) {
		asm {
			 in AL, DX;
			mov ret, AL;
		}
	} else static if (isShort!T) {
		asm {
			 in AX, DX;
			mov ret, AX;
		}
	} else static if (isInt!T) {
		asm {
			 in EAX, DX;
			mov ret, EAX;
		}
	} else
		static assert(0);

	return ret;
}

void Out(T = ubyte)(ushort port, T d) {
	uint data = d;
	asm {
		mov EAX, data;
		mov DX, port;
	}

	static if (isByte!T) {
		asm {
			out DX, AL;
		}
	} else static if (isShort!T) {
		asm {
			out DX, AX;
		}
	} else static if (isInt!T) {
		asm {
			out DX, EAX;
		}
	} else
		static assert(0);
}
