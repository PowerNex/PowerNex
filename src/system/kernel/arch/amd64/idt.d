module arch.amd64.idt;

import stl.register;
import stl.bitfield;
import io.port;

align(1) struct IDTBase {
align(1):
	ushort limit;
	ulong offset;
}

static assert(IDTBase.sizeof == 10);

struct IDTDescriptor {
align(1):
	ushort targetLow;
	ushort segment;
	private ushort _flags;
	ushort targetMiddle;
	uint targetHigh;
	private uint _reserved;

	mixin(bitfield!(_flags, "ist", 3, "zero0", 5, "type", 4, "zero1", 1, "dpl", 2, "p", 1));
}

static assert(IDTDescriptor.sizeof == 16);

enum IDTFlags : ubyte {
	interupt = 0xE,
	present = 0x80,
	privilegeLevel3 = 0x60
}

enum InterruptType : ubyte {
	divisionByZero = 0,
	debugger = 0x1,
	nmi = 0x2,
	breakpoint = 0x3,
	overflow = 0x4,
	bounds = 0x5,
	invalidOpcode = 0x6,
	coprocessorNotAvailable = 0x7,
	doubleFault = 0x8,
	coprocessorSegmentOverrun = 0x9, // (386 or earlier only)
	invalidTaskStateSegment = 0xA,
	segmentNotPresent = 0xB,
	stackFault = 0xC,
	generalProtectionFault = 0xD,
	pageFault = 0xE,
	reserved = 0xF,
	mathFault = 0x10,
	alignmentCheck = 0x11,
	machineCheck = 0x12,
	simdFloatingPointException = 0x13
}

enum SystemSegmentType : ubyte {
	localDescriptorTable = 0b0010,
	availableTSS = 0b1001,
	busyTSS = 0b1011,
	callGate = 0b1100,
	interruptGate = 0b1110,
	trapGate = 0b1111
}

enum InterruptStackType : ushort {
	registerStack,
	stackFault,
	doubleFault,
	nmi,
	debug_,
	mce
}

alias irq = (ubyte x) => cast(ubyte) (0x20 + x);

static struct IDT {
public:
	alias InterruptCallback = void function(Registers* regs);
	__gshared IDTBase base;
	__gshared IDTDescriptor[256] desc;
	__gshared InterruptCallback[256] handlers;

	static void init() {
		base.limit = (IDTDescriptor.sizeof * desc.length) - 1;
		base.offset = cast(ulong)desc.ptr;

		_addAllJumps();
	}

	static void flush() {
		void* baseAddr = (&base);
		asm pure nothrow {
			mov RAX, baseAddr;
			lidt [RAX];
		}
	}

	static void register(uint id, InterruptCallback cb) {
		handlers[id] = cb;
	}

private:
	static void _add(uint id, SystemSegmentType gateType, ulong func, ubyte dplFlags, ubyte istFlags) {
		with (desc[id]) {
			targetLow = func & 0xFFFF;
			segment = 0x08;
			ist = istFlags;
			p = true;
			dpl = dplFlags;
			type = cast(uint)gateType;
			targetMiddle = (func >> 16) & 0xFFFF;
			targetHigh = (func >> 32) & 0xFFFF_FFFF;
		}
	}

	static void _addAllJumps() {
		mixin(_addJumps!(0, 255));
		_add(3, SystemSegmentType.interruptGate, cast(ulong)&isr3, 3, InterruptStackType.debug_);
		_add(8, SystemSegmentType.interruptGate, cast(ulong)&isrIgnore, 0, InterruptStackType.registerStack);
		_add(0x80, SystemSegmentType.interruptGate, cast(ulong)&isr128, 3, InterruptStackType.registerStack);

		flush();
	}

	static template _generateJump(ulong id, bool hasError = false) {
		enum _generateJump = `
			static void isr` ~ id.stringof[0 .. $ - 2] ~ `() {
				asm pure nothrow {
					naked;
					` ~ (hasError ? "" : "push 0UL;") ~ `
					push `
				~ id.stringof ~ `;

					jmp isrCommon;
				}
			}
		`;
	}

	static template _generateJumps(ulong from, ulong to, bool hasError = false) {
		static if (from <= to)
			enum _generateJumps = _generateJump!(from, hasError) ~ _generateJumps!(from + 1, to, hasError);
		else
			enum _generateJumps = "";
	}

	static template _addJump(ulong id) {
		enum _addJump = `
			_add(` ~ id.stringof[0 .. $ - 2] ~ `, SystemSegmentType.interruptGate, cast(ulong)&isr`
				~ id.stringof[0 .. $ - 2] ~ `, 0, InterruptStackType.registerStack);`;
	}

	static template _addJumps(ulong from, ulong to) {
		static if (from <= to)
			enum _addJumps = _addJump!from ~ _addJumps!(from + 1, to);
		else
			enum _addJumps = "";
	}

	mixin(_generateJumps!(0, 7));
	mixin(_generateJump!(8, true));
	mixin(_generateJump!(9));
	mixin(_generateJumps!(10, 14, true));
	mixin(_generateJumps!(15, 255));

	static void isrIgnore() {
		asm pure nothrow {
			naked;
			cli;
			nop;
			nop;
			nop;

			db 0x48, 0xCF; //iretq;
		}
	}

	extern (C) static void isrCommon() {
		asm pure nothrow {
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
		import data.textbuffer : scr = getBootTTY;
		import io.log;

		regs.intNumber &= 0xFF;
		if (32 <= regs.intNumber && regs.intNumber <= 48) {
			if (regs.intNumber >= 40)
				outp!ubyte(0xA0, 0x20);
			outp!ubyte(0x20, 0x20);
		}

		if (auto handler = handlers[regs.intNumber])
			handler(regs);
		else
			with (regs) {
				import data.color;

				scr.foreground = Color(255, 0, 0);
				scr.writeln("===> UNCAUGHT INTERRUPT");
				scr.writeln("IRQ = ", intNumber.num!InterruptType, " | RIP = ", rip);
				scr.writeln("RAX = ", rax, " | RBX = ", rbx);
				scr.writeln("RCX = ", rcx, " | RDX = ", rdx);
				scr.writeln("RDI = ", rdi, " | RSI = ", rsi);
				scr.writeln("RSP = ", rsp, " | RBP = ", rbp);
				scr.writeln(" R8 = ", r8, "  |  R9 = ", r9);
				scr.writeln("R10 = ", r10, " | R11 = ", r11);
				scr.writeln("R12 = ", r12, " | R13 = ", r13);
				scr.writeln("R14 = ", r14, " | R15 = ", r15);
				scr.writeln(" CS = ", cs, "  |  SS = ", ss);
				scr.writeln(" CR2 = ", cr2);
				scr.writeln("Flags: ", flags);
				scr.writeln("Errorcode: ", errorCode);

				Log.fatal("===> UNCAUGHT INTERRUPT", "\n", "IRQ = ", intNumber.num!InterruptType, " | RIP = ", rip, "\n",
						"RAX = ", rax, " | RBX = ", rbx, "\n", "RCX = ", rcx, " | RDX = ", rdx, "\n", "RDI = ", rdi, " | RSI = ",
						rsi, "\n", "RSP = ", rsp, " | RBP = ", rbp, "\n", " R8 = ", r8, "  |  R9 = ", r9, "\n", "R10 = ", r10,
						" | R11 = ", r11, "\n", "R12 = ", r12, " | R13 = ", r13, "\n", "R14 = ", r14, " | R15 = ", r15, "\n",
						" CS = ", cs, "  |  SS = ", ss, "\n", " CR2 = ", cr2, "\n", "Flags: ", flags, "\n", "Errorcode: ", errorCode);
			}
	}
}
