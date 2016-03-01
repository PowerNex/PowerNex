module Data.Register;

private extern (C) void* CPU_ret_cr2();

struct InterruptRegisters {
align(1):
	ulong R15, R14, R13, R12, R11, R10, R9, R8;
	ulong RBP, RDI, RSI, RDX, RCX, RBX, RAX;
	ulong IntNumber, ErrorCode;
	ulong RIP, CS, Flags, RSP, SS;

	@property void* CR2() const {
		return CPU_ret_cr2();
	}
}
