/**
 * Interface for using the io ports.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.arch.amd64.ioport;

T inp(T)(ushort port) @trusted {
	import stl.trait : isByte, isShort, isInt;

	T ret;
	asm pure @trusted nothrow @nogc {
		mov DX, port;
	}

	static if (T.sizeof == 1) {
		asm pure @trusted nothrow @nogc {
			 in AL, DX;
			mov ret, AL;
		}
	} else static if (T.sizeof == 2) {
		asm pure @trusted nothrow @nogc {
			 in AX, DX;
			mov ret, AX;
		}
	} else static if (T.sizeof == 4) {
		asm pure @trusted nothrow @nogc {
			 in EAX, DX;
			mov ret, EAX;
		}
	} else
		static assert(0);

	return ret;
}

void outp(T)(ushort port, T d) @trusted {
	import stl.trait : isByte, isShort, isInt;

	uint data = d;
	asm pure @trusted nothrow @nogc {
		mov EAX, data;
		mov DX, port;
	}

	static if (T.sizeof == 1) {
		asm pure @trusted nothrow @nogc {
			out DX, AL;
		}
	} else static if (T.sizeof == 2) {
		asm pure @trusted nothrow @nogc {
			out DX, AX;
		}
	} else static if (T.sizeof == 4) {
		asm pure @trusted nothrow @nogc {
			out DX, EAX;
		}
	} else
		static assert(0);
}
