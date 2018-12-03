module hw.pci.pci;

import stl.address;
import stl.arch.amd64.ioport;
import stl.io.log;
import stl.io.vga;
import stl.vector;

private enum {
	configAddress = 0xCF8,
	configData = 0xCFC
}

struct PCIDevice {
	this(ubyte bus, ubyte slot) {
		ushort[] raw = (&deviceID)[0 .. PCIDevice.sizeof / ushort.sizeof];
		foreach (idx, ref word; raw)
			word = PCI.readData(bus, slot, 0, cast(ubyte)(idx * ushort.sizeof));
	}

align(1):
	ushort deviceID, vendorID;
	ushort status, command;
	ubyte classCode, subClass, progIF, revisionID;
	ubyte bist, headerType, latencyTimer, cacheLineSize;
	uint bar0;
	uint bar1;
	uint bar2;
	uint bar3;
	uint bar4;
	uint bar5;
	uint cardbusCISPointer;
	ushort subsystemID, subsystemVendorID;
	uint expandsionROMBaseAddress;
	private ushort reserved0;
	ushort capabilitiesPointer;
	private uint reserved1;
	ubyte maxLatency, minGrant, interruptPIN, interruptLine;
}

static assert(PCIDevice.sizeof == 64);

static struct PCI {
public static:
	void init() {
		_scanForDevices();
	}

	ushort readData(ubyte bus, ubyte slot, ubyte func, ubyte offset) {
		uint address = cast(uint)((bus << 16) | (slot << 11) | (func << 8) | (offset & 0xfc) | (cast(uint)0x80000000));

		outp!uint(configAddress, address);
		return cast(ushort)(inp!uint(configData) >> ((offset & 2) * 8));
	}

	PCIDevice* getDevice(ushort deviceID, ushort vendorID) {
		foreach (ref PCIDevice device; _devices)
			if (device.deviceID == deviceID && device.vendorID == vendorID)
				return &device;
		return null;
	}

private static:
	__gshared Vector!(PCIDevice, 128) _devices;

	void _scanForDevices() {
		for (ubyte bus = 0; bus < 255; bus++)
			for (ubyte slot = 0; slot < 32; slot++) {
				if (!_deviceExist(bus, slot))
					continue;

				if ((readData(bus, slot, 0, 0x0C) & 0xFF) == 0xFF)
					continue;

				_devices.put(PCIDevice(bus, slot));
				PCIDevice* device = &_devices[$ - 1];

				Log.info("Found device at ", cast(void*)bus, ":", cast(void*)slot);
				Log.info("\tdeviceID: ", cast(void*)device.deviceID, " vendorID: ", cast(void*)device.vendorID, " type: ",
						device.headerType & 0x7E, " mf?: ", !!device.headerType & 0x80);
				VGA.writeln("Found device at ", cast(void*)bus, ":", cast(void*)slot);
				VGA.writeln("\tdeviceID: ", cast(void*)device.deviceID, " vendorID: ", cast(void*)device.vendorID, " type: ",
						device.headerType & 0x7E, " mf?: ", !!device.headerType & 0x80);
			}
	}

	ushort _deviceExist(ubyte bus, ubyte slot, ubyte func = 0) {
		return readData(bus, slot, func, 0) != ushort.max;
	}
}
