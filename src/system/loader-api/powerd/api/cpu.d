/**
 * This stores the information about all the CPU.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module powerd.api.cpu;

import stl.address;


///
@safe struct CPUThread {
	///
	enum State : ubyte {
		on, ///
		off, ///
		disabled /// Probably broken
	}

	///
	enum Flag : ubyte {
		none = 0, ///
		lAPIC = 0 << 0, ///
		x2LAPIC = 1 << 0, ///
		bsp = 1 << 1 ///
	}

	uint id; ///
	State state; ///
	Flag flags; ///
	uint apicID; ///
	uint acpiID; ///
	uint lapicTimerFreq; ///
	//TODO:? uint domain; ///
}

///
@safe struct IOAPIC {
	ubyte id; ///
	ubyte version_; ///
	ushort gsiMaxRedirectCount; ///
	uint gsi; ///
	PhysAddress address; ///
}

///
@safe struct IRQFlags {
	import stl.bitfield : bitfield;

	///
	enum Active : ubyte {
		high = 0, ///
		low ///
	}

	///
	enum Trigger : ubyte {
		edge = 0, ///
		level ///
	}

	private ubyte data;
	mixin(bitfield!(data, "active", 1, Active, "trigger", 1, Trigger));
}

///
@safe struct PowerDCPUs {
	import stl.vector : Vector;
	Vector!(CPUThread, 32) cpuThreads; ///
	Vector!(IOAPIC, 32) ioapics; ///

	/// Map a IRQ to a GSI
	uint[16 /* IRQ (0-15) */ ] irqMap = () {
		uint[16] o;
		foreach (uint i, ref uint x; o)
			x = i;
		return o;
	}();
	IRQFlags[16] irqFlags; /// Mapping flags. See irqMap.

	VirtAddress lapicAddress;
	bool x2APIC;
	ulong cpuBusFreq;
}
