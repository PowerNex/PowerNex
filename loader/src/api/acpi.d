/**
 * This handles the API interface for the ACPI data structures.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module api.acpi;

import data.address;

/// The PowerD ACPI information container
@safe struct PowerDACPI {
	/// Needed to shutdown the PC
	struct Shutdown {
		ushort pm1aControlBlock; /// PM1a Control Block
		ushort pm1bControlBlock; /// PM1b Control Block
		ushort sleepTypeA; /// SleepType for PM1a Control Block
		ushort sleepTypeB; /// SleepType for PM1b Control Block
		enum sleepEnable = 1 << 13; /// The sleep enable flag
	}

	/// Needed to reboot the PC
	struct Reboot {
		/// The action that is needed to be able to reset the PC
		enum Action : ubyte {
			invalid = 0, /// Invalid
			io, /// Write to a IO port. See Where.ioPort.
			memory /// Write to a memory location. See Where.address.
		}

		/// Where to do the action
		struct Where {
			/// The io port. See Action.io.
			@property ushort ioPort() {
				return cast(ushort)address.num;
			}

			PhysAddress address; /// The memory location. See Action.memory.
		}

		Where where; /// Where to do the action
		Action action; /// The action that is needed to be able to reset the PC
		ubyte value; /// The value that is needed to be written to where
	}

	Shutdown shutdown; /// Needed to shutdown the PC
	Reboot reboot; /// Needed to reboot the PC

	VirtAddress rsdtV1; /// The RSDT for ACPI V.1
	VirtAddress rsdtV2; /// The RSDT for ACPI V.2+
	PhysAddress dsdt; /// The address where the DSDT structure is located
	PhysAddress lapicAddress;

	ubyte century; /// What century we are in (for offseting CMOS)
}
