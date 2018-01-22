/**
 * A $(I I/O Advanced Programmable Interrupt Controller), also called IOAPIC, helper module
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module arch.amd64.ioapic;

import stl.address;

/***
 * > The Intel I/O Advanced Programmable Interrupt Controller is used to distribute external interrupts in a more
 * > advanced manner than that of the standard 8259 PIC. With the I/O APIC, interrupts can be distributed to physical or
 * > logical (clusters of) processors and can be prioritized. Each I/O APIC typically handles 24 external interrupts.
 * - http://wiki.osdev.org/IOAPIC
 */
@safe static struct IOAPIC {
public static:
	///
	void analyze() {
		import powerd.api : getPowerDAPI;
		import powerd.api.cpu : IOAPIC;
		import arch.amd64.paging : Paging;
		import io.log : Log;

		foreach (ref IOAPIC ioapic; getPowerDAPI.cpus.ioapics) {
			VirtAddress vAddr = Paging.mapSpecialAddress(ioapic.address, 0x20, true);
			const uint data = _ioapicVer(vAddr);
			ioapic.version_ = cast(ubyte)(data & 0xFF);
			ioapic.gsiMaxRedirectCount = cast(ubyte)((data >> 16) & 0xFF) + 1;
			Log.info("IOAPIC: version: ", ioapic.version_, ", gsiMaxRedirectCount: ", ioapic.gsiMaxRedirectCount);
			Paging.unmapSpecialAddress(vAddr, 0x20);
		}
	}

	///
	void setupLoader() {
		import powerd.api : getPowerDAPI;
		import powerd.api.cpu : IOAPIC;
		import arch.amd64.paging : Paging;

		foreach (ref IOAPIC ioapic; getPowerDAPI.cpus.ioapics) {
			VirtAddress vAddr = Paging.mapSpecialAddress(ioapic.address, 0x20, true);
			foreach (i; 0 .. ioapic.gsiMaxRedirectCount) {
				const uint gsi = ioapic.gsi + i;

				_ioRedirectionTable(vAddr, i, _createRedirect(gsi));
			}
			Paging.unmapSpecialAddress(vAddr, 0x20);
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

		import stl.bitfield : bitfield;

		private ulong data;
		// dfmt off
		mixin(bitfield!(data,
			"vector", 8,
			"deliveryMode", 3, DeliveryMode,
			"destinationMode", 1, DestinationMode,
			"deliveryStatus", 1, DeliveryStatus,
			"pinPolarity", 1, PinPolarity,
			"remoteIRR ", 1,
			"triggerMode", 1, TriggerMode,
			"mask", 1,
			"destination", 8
		));
		// dfmt on
	}

	ref uint _ioregsel(VirtAddress address) {
		import powerd.api : getPowerDAPI;

		return *address.ptr!uint;
	}

	ref uint _ioregwin(VirtAddress address) {
		import powerd.api : getPowerDAPI;

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

	Redirection _ioRedirectionTable(VirtAddress address, uint irq) {
		return Redirection(cast(ulong)_read(address, irq * 2 + 1) << 32UL | cast(ulong)_read(address, irq * 2));
	}

	void _ioRedirectionTable(VirtAddress address, uint irq, Redirection redirection) {
		_write(address, irq * 2, cast(uint)redirection.data);
		_write(address, irq * 2 + 1, cast(uint)(redirection.data >> 32UL));
	}

	Redirection _createRedirect(uint gsi) {
		ubyte getIRQ(uint gsi) {
			import powerd.api : getPowerDAPI;

			foreach (ubyte irq, uint value; getPowerDAPI.cpus.irqMap)
				if (value == gsi)
					return irq;
			return ubyte.max;
		}

		Redirection redirection;
		const uint irq = getIRQ(gsi);

		// Loader info
		with (Redirection) {
			redirection.deliveryMode = DeliveryMode.fixed;
			redirection.mask = true;
			redirection.destinationMode = DestinationMode.physical;

			if (irq != ubyte.max) {
				import powerd.api : getPowerDAPI;
				import powerd.api.cpu : IRQFlags;

				const IRQFlags flags = getPowerDAPI.cpus.irqFlags[irq];
				redirection.triggerMode = flags.trigger == IRQFlags.Trigger.level ? TriggerMode.level : TriggerMode.edge;
				redirection.pinPolarity = flags.active == IRQFlags.Active.high ? PinPolarity.activeHigh : PinPolarity.activeLow;
			} else {
				// PCI-like interrupt lines (comment stolen from Hydrogen)
				redirection.triggerMode = TriggerMode.level;
				redirection.pinPolarity = PinPolarity.activeLow;
			}
		}
		return redirection;
	}
}
