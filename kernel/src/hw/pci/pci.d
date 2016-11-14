module HW.PCI.PCI;

import Data.Address;
import IO.Port;
import IO.Log;
import Data.TextBuffer : scr = GetBootTTY;

private enum {
	CONFIG_ADDRESS = 0xCF8,
	CONFIG_DATA = 0xCFC
}

struct PCIDevice {
	this(PCI pci, ubyte bus, ubyte slot) {
		ushort[] raw = (&deviceID)[0 .. PCIDevice.sizeof / ushort.sizeof];
		foreach (idx, ref word; raw)
			word = pci.ReadData(bus, slot, 0, cast(ubyte)(idx * ushort.sizeof));
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

class PCI {
public:
	this() {
		devices.length = 16;
		scanForDevices();
	}

	ushort ReadData(ubyte bus, ubyte slot, ubyte func, ubyte offset) {
		uint address = cast(uint)((bus << 16) | (slot << 11) | (func << 8) | (offset & 0xfc) | (cast(uint)0x80000000));

		Out!uint(CONFIG_ADDRESS, address);
		return cast(ushort)(In!uint(CONFIG_DATA) >> ((offset & 2) * 8));
	}

	PCIDevice* GetDevice(ushort deviceID, ushort vendorID) {
		foreach (ref device; devices[0 .. deviceCount])
			if (device.deviceID == deviceID && device.vendorID == vendorID)
				return &device;
		return null;
	}

private:
	PCIDevice[] devices;
	size_t deviceCount;
	void scanForDevices() {
		for (ubyte bus = 0; bus < 255; bus++)
			for (ubyte slot = 0; slot < 32; slot++) {
				if (!deviceExist(bus, slot))
					continue;

				if ((ReadData(bus, slot, 0, 0x0C) & 0xFF) == 0xFF)
					continue;

				if (deviceCount == devices.length)
					devices.length += 16;

				PCIDevice* device = &devices[deviceCount];

				*device = PCIDevice(this, bus, slot);

				log.Info("Found device at ", cast(void*)bus, ":", cast(void*)slot);
				log.Info("\tdeviceID: ", cast(void*)device.deviceID, " vendorID: ", cast(void*)device.vendorID,
						" type: ", device.headerType & 0x7E, " mf?: ", !!device.headerType & 0x80);
				scr.Writeln("Found device at ", cast(void*)bus, ":", cast(void*)slot);
				scr.Writeln("\tdeviceID: ", cast(void*)device.deviceID, " vendorID: ", cast(void*)device.vendorID,
						" type: ", device.headerType & 0x7E, " mf?: ", !!device.headerType & 0x80);

				deviceCount++;
			}
	}

	ushort deviceExist(ubyte bus, ubyte slot, ubyte func = 0) {
		return ReadData(bus, slot, func, 0) != ushort.max;
	}

}

PCI GetPCI() {
	import Data.Util : InplaceClass;

	__gshared ubyte[__traits(classInstanceSize, PCI)] data;
	__gshared PCI pci;

	if (!pci)
		pci = InplaceClass!PCI(data);
	return pci;
}
