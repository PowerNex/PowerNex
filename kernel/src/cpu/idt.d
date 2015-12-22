module cpu.idt;

version(X86_64) {
} else
	static assert(0, "IDT is current only for X86_64!");

import data.register;
import data.bitfield;

align(1) struct IDTBase {
align(1):
	ushort Limit;
	ulong Offset;
}
static assert(IDTBase.sizeof == 10);

struct IDTDescriptor {
align(1):
	ushort TargetLow;
	ushort Segment;
	private ushort _flags;
	ushort TargetMiddle;
	uint TargetHigh;
	private uint _reserved;

	mixin(Bitfield!(_flags, "ist", 3, "Zero0", 5, "Type", 4, "Zero1", 1, "dpl", 2, "p", 1));
}
static assert(IDTDescriptor.sizeof == 16);

enum IDTFlags : ubyte {
	Interupt = 0xE,
	Present = 0x80,
	PrivilegeLevel3 = 0x60
}

enum InterruptType : ubyte {
	DivisionByZero = 0,
	Debugger,
	NMI,
	Breakpoint,
	Overflow,
	Bounds,
	InvalidOpcode,
	CoprocessorNotAvailable,
	DoubleFault,
	CoprocessorSegmentOverrun, // (386 or earlier only)
	InvalidTaskStateSegment,
	SegmentNotPresent,
	StackFault,
	GeneralProtectionFault,
	PageFault,
	Reserved,
	MathFault,
	AlignmentCheck,
	MachineCheck,
	SIMDFloatingPointException
}

enum SystemSegmentType : ubyte {
	LocalDescriptorTable = 0b0010,
	AvailableTSS         = 0b1001,
	BusyTSS              = 0b1011,
	CallGate             = 0b1100,
	InterruptGate        = 0b1110,
	TrapGate             = 0b1111
}

enum InterruptStackType : ushort {
	RegisterStack,
	StackFault,
	DoubleFault,
	NMI,
	Debug,
	MCE
}

static struct IDT {
	__gshared IDTBase base;
	__gshared IDTDescriptor[256] desc;

	static void Init() {
		base.Limit = (IDTDescriptor.sizeof * desc.length) - 1;
		base.Offset = cast(ulong)desc.ptr;

		registerCPUInterrupts();

		Flush();
	}

	static void Flush() {
		void * baseAddr = cast(void *)(&base);
		asm {
			mov baseAddr, RAX;
			lidt [RAX];
		}
	}

	private static void add(uint id, SystemSegmentType gateType, ulong func, ushort dplFlags, ushort istFlags) {
		with(desc[id]) {
			TargetLow = func & 0xFFFF;
			Segment = 0x08;
			ist = istFlags;
			p = true;
			dpl = dplFlags;
			Type = cast(uint)gateType;
			TargetMiddle = (func >> 16) & 0xFFFF;
			TargetHigh = (func >> 32) & 0xFFFF_FFFF;
		}
	}

	private static void registerCPUInterrupts() {
		mixin(addJumps!(0, 255));
		add(3, SystemSegmentType.InterruptGate, cast(ulong)&isr3, 3, InterruptStackType.Debug);
		add(8, SystemSegmentType.InterruptGate, cast(ulong)&isrIgnore, 0, InterruptStackType.RegisterStack);
	}

	private static template generateJump(ulong id, bool hasError = false) {
		const char[] generateJump = `
			private static void isr`~id.stringof[0 .. $ - 2]~`() {
				asm {
					naked;
					`~(hasError ? "" : "push 0UL;")~`
					push `~id.stringof~`;

					jmp isrCommon;
				}
			}
		`;
	}

	private static template generateJumps(ulong from, ulong to, bool hasError = false) {
		static if (from <= to)
			const char[] generateJumps = generateJump!(from, hasError) ~ generateJumps!(from + 1, to, hasError);
		else
			const char[] generateJumps = "";
	}

	private static template addJump(ulong id) {
		const char[] addJump = `
			add(`~id.stringof[0 .. $ - 2]~`, SystemSegmentType.InterruptGate, cast(ulong)&isr`~id.stringof[0 .. $ - 2]~`, 0, InterruptStackType.RegisterStack);`;
	}

	private static template addJumps(ulong from, ulong to) {
		static if (from <= to)
			const char[] addJumps = addJump!from ~ addJumps!(from + 1, to);
		else
			const char[] addJumps = "";
	}

	mixin(generateJumps!(0, 7));
	mixin(generateJump!(8, true));
	mixin(generateJump!(9));
	mixin(generateJumps!(10, 14, true));
	mixin(generateJumps!(15, 255));

	private static void isrIgnore() {
		asm {
			naked;
			nop;
			nop;
			nop;

			db 0x48, 0xCF; //iretq;
		}
	}

	extern(C) private static void isrCommon() {
		asm {
			naked;
			cli;

			push RAX;
			push RBX;
			push RCX;
			push RDX;
			push RSI;
			push RDI;
			push RBP;
			push R8;
			push R9;
			push R10;
			push R11;
			push R12;
			push R13;
			push R14;
			push R15;

			mov RDI, RSP;
			call isrHandler;

			pop R15;
			pop R14;
			pop R13;
			pop R12;
			pop R11;
			pop R10;
			pop R9;
			pop R8;
			pop RBP;
			pop RDI;
			pop RSI;
			pop RDX;
			pop RCX;
			pop RBX;
			pop RAX;

			add RSP, 16;
			db 0x48, 0xCF; //iretq;
		}
	}

	extern(C) private static void isrHandler(InterruptRegisters * regs) {
		import io.textmode;
		GetScreen.Writeln("INTERRUPT: ", cast(InterruptType)regs.IntNumber, " Errorcode: ", regs.ErrorCode);
		import io.log;
		with (regs) {
			log.Fatal("Interrupt!\r\n",
				"\tIntNumber: ", cast(void *) IntNumber, " ErrorCode: ", cast(void *) ErrorCode, "\r\n",
				"\tRAX: ", cast(void *) RAX, " RBX: ", cast(void *) RBX, " RCX: ", cast(void *) RCX, " RDX: ", cast(void *) RDX, "\r\n",
				"\tRSI: ", cast(void *) RSI, " RDI: ", cast(void *) RDI, " RBP: ", cast(void *) RBP, "\r\n",
				"\tRIP: ", cast(void *) RIP, " RSP: ", cast(void *) RSP, " Flags: ", cast(void *) Flags, " SS: ", cast(void *) SS, " CS: ", cast(void *) CS,
			);
		}
	}
}
