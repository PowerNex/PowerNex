module io.fs.io.framebuffer.bgaframebuffer;

import io.fs;
import io.fs.io.framebuffer;
import data.address;
import io.log;
import io.port;

import hw.pci.pci;

private enum : ushort {
	vbeDispiTotalVideoMemoryMb = 16,
	vbeDispi_4BppPlaneShift = 22,
	vbeDispiBankSizeKb = 64,
	vbeDispiMaxXres = 2560,
	vbeDispiMaxYres = 1600,
	vbeDispiMaxBpp = 32,
	vbeDispiIoportIndex = 0x01CE,
	vbeDispiIoportData = 0x01CF,
	vbeDispiIndexId = 0x0,
	vbeDispiIndexXres = 0x1,
	vbeDispiIndexYres = 0x2,
	vbeDispiIndexBpp = 0x3,
	vbeDispiIndexEnable = 0x4,
	vbeDispiIndexBank = 0x5,
	vbeDispiIndexVirtWidth = 0x6,
	vbeDispiIndexVirtHeight = 0x7,
	vbeDispiIndexXOffset = 0x8,
	vbeDispiIndexYOffset = 0x9,
	vbeDispiIndexVideoMemory_64K = 0xa,
	vbeDispiId0 = 0xB0C0,
	vbeDispiId1 = 0xB0C1,
	vbeDispiId2 = 0xB0C2,
	vbeDispiId3 = 0xB0C3,
	vbeDispiId4 = 0xB0C4,
	vbeDispiId5 = 0xB0C5,
	vbeDispiBpp_4 = 0x04,
	vbeDispiBpp_8 = 0x08,
	vbeDispiBpp_15 = 0x0F,
	vbeDispiBpp_16 = 0x10,
	vbeDispiBpp_24 = 0x18,
	vbeDispiBpp_32 = 0x20,
	vbeDispiDisabled = 0x00,
	vbeDispiEnabled = 0x01,
	vbeDispiGetcaps = 0x02,
	vbeDispi8BitDac = 0x20,
	vbeDispiLfbEnabled = 0x40,
	vbeDispiNoclearmem = 0x80,
}

enum : ushort {
	bgaVendor = 0x1234,
	bgaDevice = 0x1111,
	vboxVendor = 0x80EE,
	vboxDevice = 0xBEEF,
	vboxOlddevice = 0x7145,
}
enum {
	vboxAddr = 0xE000_0000,
}

class BGAFramebuffer : Framebuffer {
public:
	this(size_t width, size_t height) {
		PhysAddress physAddress;
		PCIDevice* bgaDevice = getPCI.getDevice(bgaVendor, bgaDevice);
		if (bgaDevice)
			physAddress = PhysAddress(bgaDevice.bar0 & ~0b1111UL);
		else {
			bgaDevice = getPCI.getDevice(vboxVendor, vboxDevice);
			if (!bgaDevice)
				bgaDevice = getPCI.getDevice(vboxVendor, vboxOlddevice);
			if (!bgaDevice)
				log.fatal("BGA device not found!");
			physAddress = PhysAddress(vboxAddr);
		}

		super(physAddress, width, height);
	}

protected:
	override void onActivate() {
		ushort bitDepth = vbeDispiBpp_32;
		bool useLinearFrameBuffer = true;
		bool clearVideoMemory = true;
		_writeRegister(vbeDispiIndexEnable, vbeDispiDisabled);
		_writeRegister(vbeDispiIndexXres, cast(ushort)width);
		_writeRegister(vbeDispiIndexYres, cast(ushort)height);
		_writeRegister(vbeDispiIndexBpp, bitDepth);
		_writeRegister(vbeDispiIndexVirtWidth, cast(ushort)width);
		_writeRegister(vbeDispiIndexVirtHeight, cast(ushort)height);
		_writeRegister(vbeDispiIndexXOffset, 0);
		_writeRegister(vbeDispiIndexYOffset, 0);
		_writeRegister(vbeDispiIndexEnable, vbeDispiEnabled | (useLinearFrameBuffer ? vbeDispiLfbEnabled
				: 0) | (clearVideoMemory ? 0 : vbeDispiNoclearmem));
	}

	override void onDisable() {
		_writeRegister(vbeDispiIndexEnable, vbeDispiDisabled);
	}

private:
	void _writeRegister(ushort indexValue, ushort dataValue) {
		outp!ushort(vbeDispiIoportIndex, indexValue);
		outp!ushort(vbeDispiIoportData, dataValue);
	}

	ushort _readRegister(ushort indexValue) {
		outp!ushort(vbeDispiIoportIndex, indexValue);
		return inp!ushort(vbeDispiIoportData);
	}
}
