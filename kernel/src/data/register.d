module Data.Register;

import Data.Address;

private extern (C) VirtAddress CPU_ret_cr2();

struct Registers {
align(1):
	VirtAddress R15, R14, R13, R12, R11, R10, R9, R8;
	VirtAddress RBP, RDI, RSI, RDX, RCX, RBX, RAX;
	VirtAddress IntNumber, ErrorCode;
	VirtAddress RIP, CS, Flags, RSP, SS;

	@property VirtAddress CR2() const {
		return CPU_ret_cr2();
	}
}
