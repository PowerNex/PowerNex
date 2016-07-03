module CPU.IDT;

import Data.Register;
import Data.BitField;
import IO.Port;

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
	Debugger = 0x1,
	NMI = 0x2,
	Breakpoint = 0x3,
	Overflow = 0x4,
	Bounds = 0x5,
	InvalidOpcode = 0x6,
	CoprocessorNotAvailable = 0x7,
	DoubleFault = 0x8,
	CoprocessorSegmentOverrun = 0x9, // (386 or earlier only)
	InvalidTaskStateSegment = 0xA,
	SegmentNotPresent = 0xB,
	StackFault = 0xC,
	GeneralProtectionFault = 0xD,
	PageFault = 0xE,
	Reserved = 0xF,
	MathFault = 0x10,
	AlignmentCheck = 0x11,
	MachineCheck = 0x12,
	SIMDFloatingPointException = 0x13
}

enum SystemSegmentType : ubyte {
	LocalDescriptorTable = 0b0010,
	AvailableTSS = 0b1001,
	BusyTSS = 0b1011,
	CallGate = 0b1100,
	InterruptGate = 0b1110,
	TrapGate = 0b1111
}

enum InterruptStackType : ushort {
	RegisterStack,
	StackFault,
	DoubleFault,
	NMI,
	Debug,
	MCE
}

alias IRQ = (x) => 32 + x;

static struct IDT {
public:
	alias InterruptCallback = void function(Registers* regs);
	__gshared IDTBase base;
	__gshared IDTDescriptor[256] desc;
	__gshared InterruptCallback[256] handlers;

	static void Init() {
		base.Limit = (IDTDescriptor.sizeof * desc.length) - 1;
		base.Offset = cast(ulong)desc.ptr;

		addAllJumps();
	}

	static void Flush() {
		void* baseAddr = cast(void*)(&base);
		asm {
			mov RAX, baseAddr;
			lidt [RAX];
		}
	}

	static void Register(uint id, InterruptCallback cb) {
		handlers[id] = cb;
	}

private:
	static void add(uint id, SystemSegmentType gateType, ulong func, ubyte dplFlags, ubyte istFlags) {
		with (desc[id]) {
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

	static void addAllJumps() {
		mixin(addJumps!(0, 255));
		add(3, SystemSegmentType.InterruptGate, cast(ulong)&isr3, 3, InterruptStackType.Debug);
		add(8, SystemSegmentType.InterruptGate, cast(ulong)&isrIgnore, 0, InterruptStackType.RegisterStack);
		add(0x80, SystemSegmentType.InterruptGate, cast(ulong)&isr128, 3, InterruptStackType.RegisterStack);

		Flush();
	}

	static template generateJump(ulong id, bool hasError = false) {
		const char[] generateJump = `
			static void isr` ~ id.stringof[0 .. $ - 2] ~ `() {
				asm {
					naked;
					` ~ (hasError ? "" : "push 0UL;")
			~ `
					push ` ~ id.stringof ~ `;

					jmp isrCommon;
				}
			}
		`;
	}

	static template generateJumps(ulong from, ulong to, bool hasError = false) {
		static if (from <= to)
			const char[] generateJumps = generateJump!(from, hasError) ~ generateJumps!(from + 1, to, hasError);
		else
			const char[] generateJumps = "";
	}

	static template addJump(ulong id) {
		const char[] addJump = `
			add(` ~ id.stringof[0 .. $ - 2] ~ `, SystemSegmentType.InterruptGate, cast(ulong)&isr`
			~ id.stringof[0 .. $ - 2] ~ `, 0, InterruptStackType.RegisterStack);`;
	}

	static template addJumps(ulong from, ulong to) {
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

	static void isrIgnore() {
		asm {
			naked;
			cli;
			nop;
			nop;
			nop;

			db 0x48, 0xCF; //iretq;
		}
	}

	extern (C) static void isrCommon() {
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

	extern (C) static void isrHandler(Registers* regs) {
		import Data.TextBuffer : scr = GetBootTTY;
		import IO.Log;

		regs.IntNumber &= 0xFF;
		if (32 <= regs.IntNumber && regs.IntNumber <= 48) {
			if (regs.IntNumber >= 40)
				Out!ubyte(0xA0, 0x20);
			Out!ubyte(0x20, 0x20);
		}

		if (auto handler = handlers[regs.IntNumber])
			handler(regs);
		else
			with (regs) {
				scr.Writeln("UNCAUGHT INTERRUPT: ", cast(InterruptType)IntNumber, " Errorcode: ", ErrorCode);
				log.Fatal("Uncaught interrupt!\r\n", "\tIntNumber: ", cast(void*)IntNumber, " ErrorCode: ",
						cast(void*)ErrorCode, "\r\n", "\tRAX: ", cast(void*)RAX, " RBX: ", cast(void*)RBX, " RCX: ",
						cast(void*)RCX, " RDX: ", cast(void*)RDX, "\r\n", "\tRSI: ", cast(void*)RSI, " RDI: ",
						cast(void*)RDI, " RBP: ", cast(void*)RBP, "\r\n", "\tRIP: ", cast(void*)RIP, " RSP: ",
						cast(void*)RSP, " Flags: ", cast(void*)Flags, " SS: ", cast(void*)SS, " CS: ", cast(void*)CS);
			}
	}
}
