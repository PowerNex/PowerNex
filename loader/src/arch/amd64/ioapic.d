/**
 * A $(I I/O Advanced Programmable Interrupt Controller), also called IOAPIC, helper module
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module arch.amd64.ioapic;

import data.address;

@safe static struct IOAPIC {
public static:
	void analyze() {
		import api : APIInfo;
		import api.cpu : IOAPIC;
		import io.log : Log;

		foreach (ref IOAPIC ioapic; APIInfo.cpus.ioapics[0 .. APIInfo.cpus.ioapicCount]) {
			VirtAddress vAddr = ioapic.address.mapSpecial(0x20, true);
			const uint data = _ioapicVer(vAddr);
			ioapic.version_ = cast(ubyte)(data & 0xFF);
			ioapic.gsiMaxRedirectCount = cast(ubyte)((data >> 16) & 0xFF) + 1;
			Log.info("IOAPIC: version: ", ioapic.version_, ", gsiMaxRedirectCount: ", ioapic.gsiMaxRedirectCount);
			vAddr.unmapSpecial(0x20);
		}
	}

private static:
	struct Redirection {
		enum DeliveryMode : ubyte {
			fixed = 0,
			lowestPriority = 1,
			smi = 2,
			nmi = 4,
			init = 5,
			extINT = 7,
		}

		enum DestinationMode : ubyte {
			physical = 0,
			location = 1
		}

		enum DeliveryStatus : ubyte {
			waitingForWork = 0,
			waitingToDeliver = 1
		}

		enum PinPolarity : ubyte {
			activeHigh = 0,
			activeLow = 1
		}

		enum TriggerMode : ubyte {
			edge = 0,
			level = 1
		}

		import data.bitfield : bitfield;

		private ulong data;
		mixin(bitfield!(data, "vector", 8, "deliveryMode", 3, DeliveryMode, "destinationMode", 1, DestinationMode,
				"deliveryStatus", 1, DeliveryStatus, "pinPolarity", 1, PinPolarity, "remoteIRR ", 1, "triggerMode", 1,
				TriggerMode, "disable", 1, "destination", 8));
	}

	ref uint _ioregsel(VirtAddress address) {
		import api : APIInfo;

		return *address.ptr!uint;
	}

	ref uint _ioregwin(VirtAddress address) {
		import api : APIInfo;

		return *(address + 0x10).ptr!uint;
	}

	void _write(VirtAddress address, uint offset, uint value) {
		_ioregsel(address) = offset;
		_ioregwin(address) = value;
	}

	uint _read(VirtAddress address, uint offset) {
		_ioregsel(address) = offset;
		return _ioregwin(address);
	}

	uint _ioapicID(VirtAddress address) {
		return _read(address, 0);
	}

	uint _ioapicVer(VirtAddress address) {
		return _read(address, 1);
	}

	uint _ioapicARB(VirtAddress address) {
		return _read(address, 2);
	}

	ulong _ioRedirectionTable(VirtAddress address, uint irq) {
		return cast(ulong)_read(address, 0x10 + irq * 2 + 1) << 32UL | cast(ulong)_read(address, 0x10 + irq * 2);
	}
}
