module stl.arch.amd64.tss;

import stl.bitfield;
import stl.address;

@safe struct TSS {
align(1):
	import stl.arch.amd64.idt;

	uint res0;
	VirtAddress[3] rsp;
	uint res1;
	uint res2;
	VirtAddress[7] ist;
	uint res3;
	uint res4;
	ushort ioPermBitMapOffset = 104 /* Not used */;
	ushort res5;

	ubyte[0x1000][InterruptStackType.max] interruptStacks;

	void init() @trusted {
		foreach (idx, ref interruptStack; interruptStacks)
			ist[idx] = VirtAddress(&interruptStack[0]) + interruptStack.length;
	}

	@property ref VirtAddress rsp0() return {
		return rsp[0];
	}
}

@safe struct TSSDescriptor1 {
align(1):
	this(ref TSS tss) {
		limit0 = 0x67;
		type = 9;
		//res0 = 0;
		//dpl = 0;
		present = 1;
		//limit16 = 0;
		available = 1;
		//res1 = 0;
		//granularity = 0;

		ulong ptr = cast(ulong)&tss;
		base0 = ptr & 0xFFFF;
		base16 = (ptr >> 16) & 0xFF;
		base24 = (ptr >> 24) & 0xFF;
	}

	ushort limit0;
	ushort base0;
	ubyte base16;

	private ubyte data1;
	mixin(bitfield!(data1, "type", 4, "res0", 1, "dpl", 2, "present", 1));

	private ubyte data2;
	mixin(bitfield!(data2, "limit16", 4, "available", 1, "res1", 2, "granularity", 1));

	ubyte base24;
}

@safe struct TSSDescriptor2 {
align(1):
	this(ref TSS tss) {
		//res2 = 0;
		base32 = cast(ulong)(&tss) >> 0x20;
	}

	uint base32;
	private uint res2;
}
