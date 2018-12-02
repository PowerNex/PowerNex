/**
 * A module for interfacing with the $(I Model-specific register), also called MSR.
 * This module is mostly used for interfaceing with the FS register, which is used for $(I Thread-Local Storage).
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.arch.amd64.msr;

import stl.address;

enum MSRValue : uint {
	apicBase = 0x1B,
	x2APICRegisterBase = 0x800,
	efer = 0xC0000080,
	star = 0xC0000081,
	lStar = 0xC0000082,
	cStar = 0xC0000083,
	sfMask = 0xC0000084,
	fsBase = 0xC0000100,
	gsBase = 0xC0000101,
	gsKernelBase = 0xC0000102
}

@safe static struct MSR {
public static:
	///
	@property VirtAddress fs() @trusted {
		return _get(MSRValue.fsBase).VirtAddress;
	}

	///
	@property void fs(VirtAddress value) @trusted {
		return _set(MSRValue.fsBase, value.num);
	}

	///
	@property VirtAddress gs() @trusted {
		return _get(MSRValue.gsBase).VirtAddress;
	}

	///
	@property void gs(VirtAddress value) @trusted {
		return _set(MSRValue.gsBase, value.num);
	}

	///
	@property VirtAddress gsKernel() @trusted {
		return _get(MSRValue.gsKernelBase).VirtAddress;
	}

	///
	@property void gsKernel(VirtAddress value) @trusted {
		return _set(MSRValue.gsKernelBase, value.num);
	}

	///
	@property ulong apic() @trusted {
		return _get(MSRValue.apicBase);
	}

	///
	@property void apic(ulong value) @trusted {
		return _set(MSRValue.apicBase, value);
	}

	///
	@property ulong star() @trusted {
		return _get(MSRValue.star);
	}

	///
	@property void star(ulong value) @trusted {
		return _set(MSRValue.star, value);
	}

	///
	@property ulong lStar() @trusted {
		return _get(MSRValue.lStar);
	}

	///
	@property void lStar(ulong value) @trusted {
		return _set(MSRValue.lStar, value);
	}

	///
	@property ulong cStar() @trusted {
		return _get(MSRValue.cStar);
	}

	///
	@property void cStar(ulong value) @trusted {
		return _set(MSRValue.cStar, value);
	}

	///
	@property ulong sfMask() @trusted {
		return _get(MSRValue.sfMask);
	}

	///
	@property void sfMask(ulong value) @trusted {
		return _set(MSRValue.sfMask, value);
	}

	///
	ulong x2APICRegister(ushort offset) @trusted {
		return _get(cast(MSRValue)(MSRValue.x2APICRegisterBase + offset));
	}

	///
	void x2APICRegister(ushort offset, ulong value) @trusted {
		return _set(cast(MSRValue)(MSRValue.x2APICRegisterBase + offset), value);
	}

private static:
	ulong _get(MSRValue id) {
		uint low, high;
		asm @trusted pure nothrow {
			mov ECX, id;
			rdmsr;
			mov high, EDX;
			mov low, EAX;
		}

		return cast(ulong)high << 32UL | low;
	}

	void _set(MSRValue id, ulong value) {
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
