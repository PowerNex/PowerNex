/**
 * A module for interfacing with the $(I Model-specific register), also called MSR.
 * This module is mostly used for interfaceing with the FS register, which is used for $(I Thread-Local Storage).
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module arch.amd64.msr;

import data.address;

enum MSRValue : uint {
	efer = 0xC0000080,
	star = 0xC0000081,
	lStar = 0xC0000082,
	cStar = 0xC0000083,
	sfMask = 0xC0000084,
	fsBase = 0xC0000100,
	gsBase = 0xC0000101
}

@safe static struct MSR {
public static:
	@property VirtAddress fs() @trusted {
		return get(MSRValue.fsBase).VirtAddress;
	}

	@property void fs(VirtAddress value) @trusted {
		return set(MSRValue.fsBase, value.num);
	}

private static:
	ulong get(MSRValue id) {
		uint low, high;
		asm @trusted pure nothrow {
			mov ECX, id;
			wrmsr;
			mov high, EDX;
			mov low, EAX;
		}

		return cast(ulong)high << 32UL | low;
	}

	void set(MSRValue id, ulong value) {
		uint low = cast(uint)value;
		uint high = cast(uint)(value >> 32);
		asm @trusted pure nothrow {
			mov EAX, low;
			mov EDX, high;
			mov ECX, id;
			wrmsr;
		}
	}

}
