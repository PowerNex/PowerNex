/**
 * A module for interfacing with the $(I Interrupt Descriptor Table), also called IDT.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.arch.amd64.idt;

import stl.register;
import stl.address;

///
@safe align(1) struct IDTBase {
align(1):
	ushort limit; ///
	ulong offset; ///
}

static assert(IDTBase.sizeof == 10);
///
@safe struct IDTDescriptor {
align(1):
	import stl.bitfield : bitfield;

	ushort targetLow; ///
	ushort segment; ///
	private ushort _flags;
	ushort targetMiddle; ///
	uint targetHigh; ///
	private uint _reserved;

	mixin(bitfield!(_flags, "ist", 3, "zero0", 5, "type", 4, "zero1", 1, "dpl", 2, "p", 1));
}

static assert(IDTDescriptor.sizeof == 16);

///
enum IDTFlags : ubyte {
	interupt = 0xE, ///
	present = 0x80, ///
	privilegeLevel3 = 0x60 ///
}

///
enum InterruptType : ubyte {
	divisionByZero = 0, ///
	debugger = 0x1, ///
	nmi = 0x2, ///
	breakpoint = 0x3, ///
	overflow = 0x4, ///
	bounds = 0x5, ///
	invalidOpcode = 0x6, ///
	coprocessorNotAvailable = 0x7, ///
	doubleFault = 0x8, ///
	coprocessorSegmentOverrun = 0x9, ///
	invalidTaskStateSegment = 0xA, ///
	segmentNotPresent = 0xB, ///
	stackFault = 0xC, ///
	generalProtectionFault = 0xD, ///
	pageFault = 0xE, ///
	reserved = 0xF, ///
	mathFault = 0x10, ///
	alignmentCheck = 0x11, ///
	machineCheck = 0x12, ///
	simdFloatingPointException = 0x13 ///
}

///
enum SystemSegmentType : ubyte {
	localDescreeniptorTable = 0b0010, ///
	availableTSS = 0b1001, ///
	busyTSS = 0b1011, ///
	callGate = 0b1100, ///
	interruptGate = 0b1110, ///
	trapGate = 0b1111 ///
}

///
enum InterruptStackType : ushort {
	registerStack, ///
	stackFault, ///
	doubleFault, ///
	nmi, ///
	debug_, ///
	mce ///
}

///
alias irq = (ubyte x) => cast(ubyte)(0x20 + x);

///
@safe static struct IDT {
public static:
	alias InterruptCallback = void function(Registers* regs) @trusted; ///
	__gshared IDTBase base; ///
	__gshared IDTDescriptor[256] desc; ///
	__gshared InterruptCallback[256] handlers; ///

	///
	void init() @trusted {
		base.limit = (IDTDescriptor.sizeof * desc.length) - 1;
		base.offset = cast(ulong)desc.ptr;

		_addAllJumps();
		flush();

		register(0xD, &_onGPF);

		asm {
			sti;
		}
	}

	///
	void flush() @trusted {
		void* baseAddr = cast(void*)(&base);
		asm pure nothrow {
			mov RAX, baseAddr;
			lidt [RAX];
		}
	}

	///
	void register(ubyte id, InterruptCallback cb) @trusted {
		handlers[id] = cb;
	}

	/// Returns: The address to the old gate function
	static VirtAddress registerGate(uint id, VirtAddress gateFunction) @trusted {
		import stl.address : VirtAddress;

		auto d = &desc[id];
		VirtAddress oldFunction = ((cast(ulong)d.targetHigh << 32UL) | (cast(ulong)d.targetMiddle << 16UL) | cast(ulong)d.targetLow)
			.VirtAddress;

		_add(id, SystemSegmentType.interruptGate, gateFunction.num, 0, InterruptStackType.registerStack);

		return oldFunction;
	}

private static:
	void _add(uint id, SystemSegmentType gateType, ulong func, ubyte dplFlags, ubyte istFlags) @trusted {
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

	void _addAllJumps() {
		mixin(_addJumps!(0, 255));
		_add(3, SystemSegmentType.interruptGate, cast(ulong)&isr3, 3, InterruptStackType.debug_);
		_add(8, SystemSegmentType.interruptGate, cast(ulong)&isrIgnore, 0, InterruptStackType.registerStack);
		_add(irq(1), SystemSegmentType.interruptGate, cast(ulong)&isrIgnore, 0, InterruptStackType.registerStack);
		_add(irq(4), SystemSegmentType.interruptGate, cast(ulong)&isrIgnore, 0, InterruptStackType.registerStack);
		_add(0x80, SystemSegmentType.interruptGate, cast(ulong)&isr128, 3, InterruptStackType.registerStack);
	}

	template _generateJump(ulong id, bool hasError = false) {
		enum _generateJump = `
			 void isr` ~ id.stringof[0 .. $ - 2] ~ `() @trusted {
				asm pure nothrow {
					naked;
					` ~ (hasError ? "" : "push 0UL;") ~ `
					push ` ~ id.stringof ~ `;

					jmp isrCommon;
				}
			}
		`;
	}

	template _generateJumps(ulong from, ulong to, bool hasError = false) {
		static if (from <= to)
			enum _generateJumps = _generateJump!(from, hasError) ~ _generateJumps!(from + 1, to, hasError);
		else
			enum _generateJumps = "";
	}

	template _addJump(ulong id) {
		enum _addJump = `
			_add(` ~ id.stringof[0 .. $ - 2] ~ `, SystemSegmentType.interruptGate, cast(ulong)&isr`
				~ id.stringof[0 .. $ - 2] ~ `, 0, InterruptStackType.registerStack);`;
	}

	template _addJumps(ulong from, ulong to) {
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

	void isrIgnore() @trusted {
		asm pure nothrow {
			naked;
			cli;
			nop;
			nop;
			nop;

			db 0x48, 0xCF; //iretq;
		}
	}

	extern (C) void isrCommon() @trusted {
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

	extern (C) void isrHandler(Registers* regs) @trusted {
		//import stl.io.vga : VGA, CGASlotColor, CGAColor;
		import stl.io.log : Log;

		//import arch.amd64.pic : PIC;

		/*if (PIC.enabled) {
			if (irq(0) <= regs.intNumber && regs.intNumber <= irq(16)) {
				//import stl.arch.amd64.ioport : outp;
				if (regs.intNumber >= irq(8))
					outp!ubyte(0xA0, 0x20);
				outp!ubyte(0x20, 0x20);
			}
		}*/

		if (auto handler = handlers[regs.intNumber]) {
			handler(regs);
		} else
			with (regs) {
				import stl.text : HexInt;
				import stl.arch.amd64.lapic : LAPIC;

				size_t id = LAPIC.getCurrentID();
				Log.Func func = Log.getFuncName(rip);
				/*VGA.color = CGASlotColor(CGAColor.red, CGAColor.black);
				VGA.writeln("===> Unhandled interrupt (CPU ", id, ")");
				VGA.writeln("IRQ = ", intNumber.num!InterruptType, " (", intNumber.HexInt, ") | RIP = ", rip);
				VGA.writeln("RAX = ", rax, " | RBX = ", rbx);
				VGA.writeln("RCX = ", rcx, " | RDX = ", rdx);
				VGA.writeln("RDI = ", rdi, " | RSI = ", rsi);
				VGA.writeln("RSP = ", rsp, " | RBP = ", rbp);
				VGA.writeln(" R8 = ", r8, " |  R9 = ", r9);
				VGA.writeln("R10 = ", r10, " | R11 = ", r11);
				VGA.writeln("R12 = ", r12, " | R13 = ", r13);
				VGA.writeln("R14 = ", r14, " | R15 = ", r15);
				VGA.writeln(" CS = ", cs, " |  SS = ", ss);
				VGA.writeln("CR0 = ", cr0, " | CR2 = ", cr2);
				VGA.writeln("CR3 = ", cr3, " | CR4 = ", cr4);
				VGA.writeln("Flags = ", flags.num.HexInt, " | Errorcode = ", errorCode.num.HexInt);*/

				// dfmt off
				Log.error("===> Unhandled interrupt (CPU ", id, ")", "\n",
					"IRQ = ", intNumber.num!InterruptType, " (", intNumber.HexInt, ") | RIP = ", rip, " (", func.name, '+', func.diff.HexInt, ')', "\n",
					"RAX = ", rax, " | RBX = ", rbx, "\n",
					"RCX = ", rcx, " | RDX = ", rdx, "\n",
					"RDI = ", rdi, " | RSI = ", rsi, "\n",
					"RSP = ", rsp, " | RBP = ", rbp, "\n",
					" R8 = ", r8,  " |  R9 = ", r9, "\n",
					"R10 = ", r10, " | R11 = ", r11, "\n",
					"R12 = ", r12, " | R13 = ", r13, "\n",
					"R14 = ", r14, " | R15 = ", r15, "\n",
					" CS = ", cs,  " |  SS = ", ss, "\n",
					"CR0 = ",	cr0," | CR2 = ", cr2, "\n",
					"CR3 = ",	cr3, " | CR4 = ", cr4, "\n",
					"Flags = ", flags.num.HexInt, " | Errorcode = ", errorCode.num.HexInt);
				// dfmt on
			}
	}
}

private void _onGPF(Registers* regs) @safe {
	//import stl.io.vga : VGA, CGASlotColor, CGAColor;
	import stl.io.log : Log;
	import stl.text : HexInt;
	import stl.arch.amd64.lapic : LAPIC;

	size_t id = LAPIC.getCurrentID();
	with (regs) {
		Log.Func func = Log.getFuncName(rip);
		/*VGA.color = CGASlotColor(CGAColor.red, CGAColor.black);
		VGA.writeln("===> GeneralProtectionFault (CPU ", id, ")");
		VGA.writeln("                          | RIP = ", rip);
		VGA.writeln("RAX = ", rax, " | RBX = ", rbx);
		VGA.writeln("RCX = ", rcx, " | RDX = ", rdx);
		VGA.writeln("RDI = ", rdi, " | RSI = ", rsi);
		VGA.writeln("RSP = ", rsp, " | RBP = ", rbp);
		VGA.writeln(" R8 = ", r8, " |  R9 = ", r9);
		VGA.writeln("R10 = ", r10, " | R11 = ", r11);
		VGA.writeln("R12 = ", r12, " | R13 = ", r13);
		VGA.writeln("R14 = ", r14, " | R15 = ", r15);
		VGA.writeln(" CS = ", cs, " |  SS = ", ss);
		VGA.writeln("CR0 = ", cr0, " | CR2 = ", cr2);
		VGA.writeln("CR3 = ", cr3, " | CR4 = ", cr4);
		VGA.writeln("Flags = ", flags.num.HexInt, " | Errorcode = ", errorCode.num.HexInt);*/

		// dfmt off
		Log.error("===> GeneralProtectionFault (CPU ", id, ")", "\n",
			"                          | RIP = ", rip, " (", func.name, '+', func.diff.HexInt, ')', "\n",
			"RAX = ", rax, " | RBX = ", rbx, "\n",
			"RCX = ", rcx, " | RDX = ", rdx, "\n",
			"RDI = ", rdi, " | RSI = ", rsi, "\n",
			"RSP = ", rsp, " | RBP = ", rbp, "\n",
			" R8 = ", r8,  " |  R9 = ", r9, "\n",
			"R10 = ", r10, " | R11 = ", r11, "\n",
			"R12 = ", r12, " | R13 = ", r13, "\n",
			"R14 = ", r14, " | R15 = ", r15, "\n",
			" CS = ", cs,  " |  SS = ", ss, "\n",
			"CR0 = ",	cr0, " | CR2 = ", cr2, "\n",
			"CR3 = ",	cr3, " | CR4 = ", cr4, "\n",
			"Flags = ", flags.num.HexInt, " | Errorcode = ", errorCode.num.HexInt);
		// dfmt on

		while (true) {
			asm @trusted pure nothrow {
				hlt;
			}
		}
	}
}
