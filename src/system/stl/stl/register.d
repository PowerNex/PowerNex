/**
 * This is a helper module for accessing and storage the different CPU registers.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.register;

import stl.address : VirtAddress;

@safe struct Registers {
align(1):
	VirtAddress r15, r14, r13, r12, r11, r10, r9, r8;
	VirtAddress rbp, rdi, rsi, rdx, rcx, rbx, rax;
	VirtAddress intNumber, errorCode;
	VirtAddress rip, cs, flags, rsp, ss;

	@property VirtAddress cr0() const {
		ulong val = void;
		asm pure @trusted nothrow @nogc {
			db 0x0f, 0x20, 0xc0; // mov %cr0, %rax
			mov val, RAX;
		}
		return VirtAddress(val);
	}

	@property VirtAddress cr2() const {
		ulong val = void;
		asm pure @trusted nothrow @nogc {
			db 0x0f, 0x20, 0xd0; // mov %cr2, %rax
			mov val, RAX;
		}
		return VirtAddress(val);
	}

	@property VirtAddress cr3() const {
		ulong val = void;
		asm pure @trusted nothrow @nogc {
			db 0x0f, 0x20, 0xd8; // mov %cr3, %rax
			mov val, RAX;
		}
		return VirtAddress(val);
	}

	@property VirtAddress cr4() const {
		ulong val = void;
		asm pure @trusted nothrow @nogc {
			db 0x0f, 0x20, 0xe0; // mov %cr4, %rax
			mov val, RAX;
		}
		return VirtAddress(val);
	}
}
