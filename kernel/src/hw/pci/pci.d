module hw.pci.pci;

import data.address;
import io.port;
import io.log;
import memory.allocator;
import data.textbuffer : scr = getBootTTY;

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
		_devices = makeArray!PCIDevice(kernelAllocator, 16);
		_scanForDevices();
	}

	ushort readData(ubyte bus, ubyte slot, ubyte func, ubyte offset) {
		uint address = cast(uint)((bus << 16) | (slot << 11) | (func << 8) | (offset & 0xfc) | (cast(uint)0x80000000));

		outp!uint(configAddress, address);
		return cast(ushort)(inp!uint(configData) >> ((offset & 2) * 8));
	}

	PCIDevice* getDevice(ushort deviceID, ushort vendorID) {
		foreach (ref device; _devices[0 .. _deviceCount])
			if (device.deviceID == deviceID && device.vendorID == vendorID)
				return &device;
		return null;
	}

private static:
	__gshared PCIDevice[] _devices;
	__gshared size_t _deviceCount;

	void _scanForDevices() {
		for (ubyte bus = 0; bus < 255; bus++)
			for (ubyte slot = 0; slot < 32; slot++) {
				if (!_deviceExist(bus, slot))
					continue;

				if ((readData(bus, slot, 0, 0x0C) & 0xFF) == 0xFF)
					continue;

				if (_deviceCount == _devices.length)
					if (!expandArray!PCIDevice(kernelAllocator, _devices, 16))
						log.fatal("Can't expand PCIDevices array!");

				PCIDevice* device = &_devices[_deviceCount];

				*device = PCIDevice(bus, slot);

				log.info("Found device at ", cast(void*)bus, ":", cast(void*)slot);
				log.info("\tdeviceID: ", cast(void*)device.deviceID, " vendorID: ", cast(void*)device.vendorID, " type: ",
						device.headerType & 0x7E, " mf?: ", !!device.headerType & 0x80);
				scr.writeln("Found device at ", cast(void*)bus, ":", cast(void*)slot);
				scr.writeln("\tdeviceID: ", cast(void*)device.deviceID, " vendorID: ", cast(void*)device.vendorID, " type: ",
						device.headerType & 0x7E, " mf?: ", !!device.headerType & 0x80);

				_deviceCount++;
			}
	}

	ushort _deviceExist(ubyte bus, ubyte slot, ubyte func = 0) {
		return readData(bus, slot, func, 0) != ushort.max;
	}
}
