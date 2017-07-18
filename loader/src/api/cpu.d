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
	PhysAddress address; //
	uint gsi; ///
}

///
struct IRQFlags {
	import data.bitfield : bitfield;

	///
	enum Active : ubyte {
		high, ///
		low ///
	}

	///
	enum Trigger : ubyte {
		edge, ///
		level ///
	}

	private ubyte data;
	mixin(bitfield!(data, "active", 1, Active, "trigger", 1, Trigger));
}

@safe struct PowerDCPUs {
	CPU[32] cpus; ///
	IOAPIC[2] ioAPICs; ///

	uint[16 /* IRQ (0-15) */ ] irqMap; /// Map a IRQ to a GSI
	IRQFlags[16] irqFlags; /// Mapping flags. See irqMap.
}

static assert(PowerDCPUs.sizeof <= 1024, "Please update the size for PowerDCPUs inside of loaderData.S!");
