module data.register;

import data.address : VirtAddress;

private extern (C) VirtAddress cpuRetCR2();

struct Registers {
align(1):
	VirtAddress r15, r14, r13, r12, r11, r10, r9, r8;
	VirtAddress rbp, rdi, rsi, rdx, rcx, rbx, rax;
	VirtAddress intNumber, errorCode;
	VirtAddress rip, cs, flags, rsp, ss;

	@property VirtAddress cr2() const {
		return cpuRetCR2();
	}
}
