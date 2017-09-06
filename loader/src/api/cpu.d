/**
 * This stores the information about all the CPU.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module api.cpu;

import data.address;

///
@safe struct CPU {
	///
	enum Flags : uint {
		lAPIC = 1 << 0, //
		x2LAPIC = 1 << 1 //
	}

	uint apicID; ///
	uint acpiID; ///
	Flags flags; ///
	uint lapicTimerFreq; ///
	uint domain; ///
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
	import data.bitfield : bitfield;

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

@safe struct PowerDCPUs {
	size_t cpuCount; ///
	CPU[32] cpus; ///
	size_t ioapicCount; ///
	IOAPIC[2] ioapics; ///

	/// Map a IRQ to a GSI
	uint[16 /* IRQ (0-15) */ ] irqMap = () {
		uint[16] o;
		foreach (uint i, ref uint x; o)
			x = i;
		return o;
	}();
	IRQFlags[16] irqFlags; /// Mapping flags. See irqMap.
}

static assert(PowerDCPUs.sizeof <= 1024, "Please update the size for PowerDCPUs inside of loaderData.S!");
