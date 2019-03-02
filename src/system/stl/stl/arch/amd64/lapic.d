/**
 * A $(I Local Advanced Programmable Interrupt Controller), also called LAPIC, helper module
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.arch.amd64.lapic;

import stl.address;
import stl.register;

private extern __gshared extern (C) VirtAddress LAPIC_address;
private extern extern (C) void LAPIC_dummyTimer();
private extern extern (C) void LAPIC_dummyTimerx2();
private extern extern (C) void LAPIC_spuriousTimer();

/***
 * > APIC ("Advanced Programmable Interrupt Controller") is the updated Intel standard for the older PIC. It is used in
 * > multiprocessor systems and is an integral part of all recent Intel (and compatible) processors. The APIC is used
 * > for sophisticated interrupt redirection,and for sending interrupts between processors. These things weren't
 * > possible using the older PIC specification.
 *
 * > In an APIC-based system, each CPU is made of a "core" and a "local APIC". The local APIC is responsible for
 * > handling cpu-specific interrupt configuration. Among other things, it contains the Local Vector Table (LVT) that
 * > translates events such as "internal clock" and other "local" interrupt sources into a interrupt vector
 * - http://wiki.osdev.org/APIC
 */
@safe static struct LAPIC {
public static:
	alias ExternalTickFunction = void function(Registers* regs) @safe;

	///
	void init() @trusted {
		import powerd.api : getPowerDAPI;
		import powerd.api.cpu : CPUThread;
		import stl.arch.amd64.msr : MSR;
		import stl.arch.amd64.idt : IDT;
		import stl.io.log : Log;

		{ // check cpuid for x2apic
			enum x2APICFlag = 1 << 21;
			uint ecxValue = void;
			asm pure @trusted nothrow @nogc {
				mov EAX, 1;
				cpuid;
				mov ecxValue, ECX;
			}

			_x2APIC = !!(ecxValue & x2APICFlag);
			_x2APIC = false; //TODO: X2APIC breaks booting of APs
			getPowerDAPI.cpus.x2APIC = _x2APIC;
			Log.info("X2APIC support: ", _x2APIC);
		}

		{ // Enable lapic
			enum xAPICEnableFlag = 1 << 11;
			enum x2APICEnableFlag = 1 << 10;
			ulong apicBase = MSR.apic;

			apicBase |= xAPICEnableFlag;
			if (_x2APIC)
				apicBase |= x2APICEnableFlag;

			MSR.apic = apicBase;
		}

		if (!_x2APIC) {
			if (!_lapicAddress) {
				import stl.vmm.paging : mapAddress, VMPageFlags, makeAddress;

				_lapicAddress = makeAddress(510, 0, 1, 0);
				mapAddress(_lapicAddress, getPowerDAPI.acpi.lapicAddress, VMPageFlags.present | VMPageFlags.writable, false);
				() @trusted { LAPIC_address = _lapicAddress; }();
				getPowerDAPI.cpus.lapicAddress = _lapicAddress;
			}
			_write(Registers.logicalDestination, 1 << ((getCurrentID() % 8) + 24));
		}
	}

	void init(bool x2APIC, VirtAddress lapicAddress, ulong cpuBusFreq) @trusted {
		_x2APIC = x2APIC;
		_lapicAddress = lapicAddress;
		_cpuBusFreq = cpuBusFreq;
	}

	/*///
	void cleanup() {
		if (!_x2APIC) {
			import stl.vmm.paging : unmapSpecialAddress;

			unmapSpecialAddress(_lapicAddress, 0x1000);
		}
	}*/

	void calibrate() @trusted {
		import stl.arch.amd64.idt : IDT, irq;
		import stl.arch.amd64.msr : MSR;
		import stl.io.log : Log;

		VirtAddress oldIRQ0;
		if (_x2APIC)
			oldIRQ0 = IDT.registerGate(irq(0), VirtAddress(&LAPIC_dummyTimerx2));
		else
			oldIRQ0 = IDT.registerGate(irq(0), VirtAddress(&LAPIC_dummyTimer));
		VirtAddress oldIRQ255 = IDT.registerGate(255, VirtAddress(&LAPIC_spuriousTimer));

		// Setup

		if (!_x2APIC)
			_write(Registers.destinationFormat, uint.max);

		_write(Registers.localVectorTablePerformanceMonitor, () {
			LocalVectorTable lvt;
			lvt.messageType = MessageType.nmi;
			return lvt.data;
		}());
		_write(Registers.localVectorTableLInt0, LocalVectorTable.disabled.data);
		_write(Registers.localVectorTableLInt1, LocalVectorTable.disabled.data);
		_write(Registers.localVectorTableError, LocalVectorTable.disabled.data);
		_write(Registers.taskPriority, 0);

		_write(Registers.spurious, () { Spurious s; s.vector = 255; s.enabled = true; return s.data; }());
		_write(Registers.localVectorTableTimer, () { LVTTimer timer; timer.vector = irq(0); return timer.data; }());
		_write(Registers.timerDivide, divition);

		{
			import stl.arch.amd64.ioport : outp, inp;

			enum ushort ch2IOPort = 0x61;
			enum ushort dataPort = 0x42;
			enum ushort commandPort = 0x43;

			outp!ubyte(ch2IOPort, (inp!ubyte(ch2IOPort) & ~0x2) | 1);

			{
				enum ubyte ch2 = 0b10 << 6;
				enum ubyte accessModeLoHi = 0b11 << 4;
				enum ubyte oneshort = 0b001 << 1;
				enum ubyte binary16bit = 0b0 << 0;

				outp!ubyte(commandPort, ch2 | accessModeLoHi | oneshort | binary16bit);
			}
			{
				enum pitFreq = 119_3180U;
				static assert(pitFreq / pitHZ <= ushort.max, "PIT HZ is toooooooo fast");
				ushort speed = cast(ushort)(pitFreq / pitHZ);
				outp!ubyte(dataPort, cast(ubyte)(speed & 0xFF));
				cast(void)inp!ubyte(0x60); // small delay
				outp!ubyte(dataPort, cast(ubyte)(speed >> 8));
			}

			_write(Registers.timerInitialCount, uint.max);

			size_t oldTSC = 1337;
			asm @trusted {
				rdtsc;
				mov oldTSC, RAX;
			}

			// reset PIT one-shot counter (start counting)
			immutable ubyte tmp = inp!ubyte(ch2IOPort) & ~0x1;
			outp!ubyte(ch2IOPort, tmp);
			outp!ubyte(ch2IOPort, tmp | 1);

			while (true) {
				if (!(inp!ubyte(ch2IOPort) & 0x20))
					break;
			}
			_write(Registers.localVectorTableTimer, LVTTimer.disabled.data);
			size_t newTSC = 1337;
			asm @trusted {
				rdtsc;
				mov newTSC, RAX;
			}

			immutable uint counterValue = _read(Registers.timerCurrentCount);
			_cpuBusFreq = uint.max - counterValue + 1;
			_cpuBusFreq *= divitionPower;
			_cpuBusFreq *= pitHZ;

			{
				import stl.arch.amd64.tsc : TSC;

				const size_t freq = (newTSC - oldTSC) / (1000 / pitHZ);
				Log.info("TSC freq: ", freq);
				TSC.frequency = freq;
			}

			{
				import powerd.api : getPowerDAPI;
				import stl.arch.amd64.tsc : TSC;

				getPowerDAPI.cpus.cpuBusFreq = _cpuBusFreq;
				getPowerDAPI.cpus.tscFreq = TSC.frequency;
			}
		}

		IDT.registerGate(255, oldIRQ255);
		IDT.registerGate(irq(0), oldIRQ0);
	}

	void setup() @trusted {
		import stl.arch.amd64.idt : IDT, irq;

		IDT.register(irq(0), cast(IDT.InterruptCallback)&_onTick);
		IDT.register(cast(ubyte)254, cast(IDT.InterruptCallback)&_onError);
		IDT.register(cast(ubyte)255, cast(IDT.InterruptCallback)&_onSpurious);

		_write(Registers.spurious, () { Spurious s; s.vector = 255; s.enabled = true; return s.data; }());
		_write(Registers.taskPriority, 0);
		_write(Registers.endOfInterrupt, 0);
		_write(Registers.errorStatus, 0);

		_write(Registers.localVectorTableLInt0, () {
			LocalVectorTable lvt;
			lvt.messageType = MessageType.externalInterrupt;
			lvt.triggerMode = TriggerMode.edge;
			return lvt.data;
		}());
		_write(Registers.localVectorTableLInt1, () { LocalVectorTable lvt; lvt.messageType = MessageType.nmi; return lvt.data; }());
		_write(Registers.localVectorTableError, () { LocalVectorTable lvt; lvt.vector = 254; return lvt.data; }());

		uint timerCountValue = cast(uint)(_cpuBusFreq / apicTimerHZ / divitionPower);
		if (timerCountValue < divitionPower)
			timerCountValue = divitionPower;

		//_setTimer(irq(0), TimerMode.periodic, timerCountValue, divition);
		_write(Registers.localVectorTableTimer, LVTTimer.disabled.data);
	}

	void clear() @trusted {
		_counter = 0;
	}

	@property size_t seconds() @trusted {
		return _counter / 1000;
	}

	void init(uint destination, bool assert_) @trusted {
		InterruptCommand ic;
		ic.deliveryMode = DeliveryMode.init;
		ic.level = assert_ ? Level.assert_ : Level.deassert;

		if (_x2APIC)
			_write64(Registers.interruptCommand, ic.data | (cast(ulong)destination << 32UL));
		else {
			_write(Registers._interruptCommandHigh, destination << 24);
			_write(Registers.interruptCommand, ic.data);
		}
	}

	/// Entrypoint is (address >> 12)
	void startup(uint destination, PhysAddress32 entrypointPage) @trusted {
		InterruptCommand ic;
		ic.vector = (entrypointPage >> 12).num!ubyte;
		ic.deliveryMode = DeliveryMode.startup;
		ic.level = Level.assert_;

		if (_x2APIC)
			_write64(Registers.interruptCommand, ic.data | (cast(ulong)destination << 32UL));
		else {
			_write(Registers._interruptCommandHigh, destination << 24);
			_write(Registers.interruptCommand, ic.data);
		}
	}

	uint getCurrentID() @trusted {
		uint id = _read(Registers.apicID);
		return _x2APIC ? id : (id >> 24);
	}

	void setTimerToTrigger(uint msec) @trusted {
		import stl.arch.amd64.idt : irq;

		uint timerCountValue = cast(uint)((msec * _cpuBusFreq / 1000) / divitionPower);
		if (timerCountValue < divitionPower)
			timerCountValue = divitionPower;
		_setTimer(irq(0), TimerMode.oneShot, timerCountValue, divition);
	}

	@property ulong cpuBusFreq() @trusted {
		return _cpuBusFreq;
	}

	@property void externalTick(ExternalTickFunction externalTick) @trusted {
		_externalTick = externalTick;
	}

private static:
	enum Registers : ushort {
		apicID = 0x2,
		apicVersion = 0x3,
		taskPriority = 0x8,
		endOfInterrupt = 0x0B,
		logicalDestination = 0x0D,
		destinationFormat = 0x0E, // ONLY VALID FOR MMIO
		spurious = 0x0F,
		errorStatus = 0x28,
		interruptCommand = 0x30,
		_interruptCommandHigh = 0x31, // ONLY VALID FOR MMIO // WRITE TO FIRST!
		localVectorTableTimer = 0x32,
		localVectorTablePerformanceMonitor = 0x34,
		localVectorTableLInt0 = 0x35,
		localVectorTableLInt1 = 0x36,
		localVectorTableError = 0x37,
		timerInitialCount = 0x38,
		timerCurrentCount = 0x39,
		timerDivide = 0x3E
	}

	enum DeliveryMode : ubyte {
		fixed = 0b000,
		smi = 0b010,
		nmi = 0b100,
		init = 0b101,
		startup = 0b110
	}

	enum DestinationMode {
		physical = 0,
		logical
	}

	enum Level {
		deassert = 0,
		assert_
	}

	enum DestinationShorthand {
		noShorthand = 0b00,
		self = 0b01,
		allIncludingSelf = 0b10,
		allExcludingSelf = 0b11,
	}

	// Register.interruptCommand
	struct InterruptCommand {
		import stl.bitfield : bitfield;

		uint data;
		// dfmt off
		mixin(bitfield!(data,
			"vector", 8,
			"deliveryMode", 3, DeliveryMode,
			"destinationMode", 1, DestinationMode,
			"deliveryStatus", 1,
			"zero0", 1,
			"level", 1, Level,
			"triggerMode", 1, TriggerMode,
			"zero1", 2,
			"destinationShorthand", 2, DestinationShorthand,
			"zero2", 12/*,
			"destination", 32*/
		));
		// dfmt on
	}

	enum MessageType {
		fixed = 0,
		smi = 2,
		nmi = 4,
		externalInterrupt = 7
	}

	enum TriggerMode : bool {
		edge = 0,
		level = 1
	}

	// Register.localVectorTable* (not Timer)
	struct LocalVectorTable {
		import stl.bitfield : bitfield;

		enum LocalVectorTable disabled = () { LocalVectorTable lvt; lvt.mask = true; return lvt; }();

		uint data;
		// dfmt off
		mixin(bitfield!(data,
			"vector", 8,
			"messageType", 3, MessageType,
			"zero0", 1,
			"deliveryStatus", 1,

			// These three are only valid for LINTx
			"pinPolarity", 1,
			"remoteIRR", 1, // ReadOnly
			"triggerMode", 1, TriggerMode,

			"mask", 1
		));
		// dfmt on
	}

	enum TimerMode {
		oneShot = 0,
		periodic = 1,
		tscDeadline = 2
	}

	// Register.localVectorTableTimer
	struct LVTTimer {
		import stl.bitfield : bitfield;

		enum LVTTimer disabled = () { LVTTimer timer; timer.mask = true; return timer; }();

		uint data;
		// dfmt off
		mixin(bitfield!(data,
			"vector", 8,
			"zero0", 4,
			"deliveryStatus", 1,
			"zero1", 3,
			"mask", 1,
			"timerMode", 1, TimerMode
		));
		// dfmt on
	}

	// Register.spurious
	struct Spurious {
		import stl.bitfield : bitfield;

		uint data;
		// dfmt off
		mixin(bitfield!(data,
			"vector", 8,
			"enabled", 1,
			"zero0", 3,
			"eoiBroadcastDisable", 1,
			"zero1", 19
		));
		// dfmt on
	}

	alias toDivition = (ubyte d) => ((d & 0b100) << 1) + (d & 0b11);

	enum divitionPower = 16;
	enum divition = toDivition(3); // log(2;16) - 1 = 3;
	enum pitHZ = 100;
	enum apicTimerHZ = 1000; // Else the sleep won't be in ms

	__gshared VirtAddress _lapicAddress;
	__gshared bool _x2APIC;
	__gshared ulong _cpuBusFreq;

	__gshared size_t _counter;

	__gshared void function(Registers* regs) @safe _externalTick;

	uint _read(Registers offset) @trusted {
		import stl.arch.amd64.msr : MSR;

		if (_x2APIC)
			return cast(uint)MSR.x2APICRegister(cast(ushort)offset);
		else if (_lapicAddress)
			return *(_lapicAddress + offset * 0x10).ptr!uint;
		else
			return 0; // INVALID
	}

	void _write(Registers offset, uint value) @trusted {
		import stl.arch.amd64.msr : MSR;

		if (_x2APIC)
			MSR.x2APICRegister(cast(ushort)offset, value);
		else if (_lapicAddress)
			*(_lapicAddress + offset * 0x10).ptr!uint = value;
		else
			return; // INVALID
	}

	ulong _read64(Registers offset) @trusted {
		import stl.arch.amd64.msr : MSR;

		if (!_x2APIC)
			return 0;

		return MSR.x2APICRegister(cast(ushort)offset);
	}

	void _write64(Registers offset, ulong value) @trusted {
		import stl.arch.amd64.msr : MSR;

		if (!_x2APIC)
			return;

		MSR.x2APICRegister(cast(ushort)offset, value);
	}

	// Setup lapic timer
	void _setTimer(ubyte vector, TimerMode timerMode, uint initialCount, uint divide) {
		LVTTimer lvt;
		lvt.vector = vector;
		lvt.timerMode = timerMode;
		_write(Registers.timerDivide, divide);
		_write(Registers.localVectorTableTimer, lvt.data);
		_write(Registers.timerInitialCount, initialCount);
	}

	void _onTick(Registers* regs) @trusted {
		import stl.io.log : Log;

		_write(Registers.endOfInterrupt, 0);

		_counter++;

		if (_externalTick)
			_externalTick(regs);
	}

	void _onError(Registers* regs) @trusted {
		import stl.io.log : Log;

		_write(Registers.endOfInterrupt, 0);

		Log.error("onError");
	}

	void _onSpurious(Registers* regs) @trusted {
		import stl.io.log : Log;

		//_write(Registers.endOfInterrupt, 0);

		Log.warning("onSpurious");
	}
}
