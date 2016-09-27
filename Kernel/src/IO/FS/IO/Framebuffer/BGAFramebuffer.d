module IO.FS.IO.Framebuffer.BGAFramebuffer;

import IO.FS;
import IO.FS.IO.Framebuffer;
import Data.Address;
import IO.Log;
import IO.Port;

import HW.PCI.PCI;

private enum : ushort {
	VBE_DISPI_TOTAL_VIDEO_MEMORY_MB = 16,
	VBE_DISPI_4BPP_PLANE_SHIFT = 22,
	VBE_DISPI_BANK_SIZE_KB = 64,
	VBE_DISPI_MAX_XRES = 2560,
	VBE_DISPI_MAX_YRES = 1600,
	VBE_DISPI_MAX_BPP = 32,
	VBE_DISPI_IOPORT_INDEX = 0x01CE,
	VBE_DISPI_IOPORT_DATA = 0x01CF,
	VBE_DISPI_INDEX_ID = 0x0,
	VBE_DISPI_INDEX_XRES = 0x1,
	VBE_DISPI_INDEX_YRES = 0x2,
	VBE_DISPI_INDEX_BPP = 0x3,
	VBE_DISPI_INDEX_ENABLE = 0x4,
	VBE_DISPI_INDEX_BANK = 0x5,
	VBE_DISPI_INDEX_VIRT_WIDTH = 0x6,
	VBE_DISPI_INDEX_VIRT_HEIGHT = 0x7,
	VBE_DISPI_INDEX_X_OFFSET = 0x8,
	VBE_DISPI_INDEX_Y_OFFSET = 0x9,
	VBE_DISPI_INDEX_VIDEO_MEMORY_64K = 0xa,
	VBE_DISPI_ID0 = 0xB0C0,
	VBE_DISPI_ID1 = 0xB0C1,
	VBE_DISPI_ID2 = 0xB0C2,
	VBE_DISPI_ID3 = 0xB0C3,
	VBE_DISPI_ID4 = 0xB0C4,
	VBE_DISPI_ID5 = 0xB0C5,
	VBE_DISPI_BPP_4 = 0x04,
	VBE_DISPI_BPP_8 = 0x08,
	VBE_DISPI_BPP_15 = 0x0F,
	VBE_DISPI_BPP_16 = 0x10,
	VBE_DISPI_BPP_24 = 0x18,
	VBE_DISPI_BPP_32 = 0x20,
	VBE_DISPI_DISABLED = 0x00,
	VBE_DISPI_ENABLED = 0x01,
	VBE_DISPI_GETCAPS = 0x02,
	VBE_DISPI_8BIT_DAC = 0x20,
	VBE_DISPI_LFB_ENABLED = 0x40,
	VBE_DISPI_NOCLEARMEM = 0x80,
}

enum : ushort {
	BGA_VENDOR = 0x1234,
	BGA_DEVICE = 0x1111,
	VBOX_VENDOR = 0x80EE,
	VBOX_DEVICE = 0xBEEF,
	VBOX_OLDDEVICE = 0x7145,
}
enum {
	VBOX_ADDR = 0xE000_0000,
}

class BGAFramebuffer : Framebuffer {
public:
	this(size_t width, size_t height) {
		PhysAddress physAddress;
		PCIDevice* bgaDevice = GetPCI.GetDevice(BGA_VENDOR, BGA_DEVICE);
		if (bgaDevice)
			physAddress = PhysAddress(bgaDevice.bar0 & ~0b1111UL);
		else {
			bgaDevice = GetPCI.GetDevice(VBOX_VENDOR, VBOX_DEVICE);
			if (!bgaDevice)
				bgaDevice = GetPCI.GetDevice(VBOX_VENDOR, VBOX_OLDDEVICE);
			if (!bgaDevice)
				log.Fatal("BGA device not found!");
			physAddress = PhysAddress(VBOX_ADDR);
		}

		super(physAddress, width, height);
	}

protected:
	override void OnActivate() {
		ushort bitDepth = VBE_DISPI_BPP_32;
		bool useLinearFrameBuffer = true;
		bool clearVideoMemory = true;
		writeRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);
		writeRegister(VBE_DISPI_INDEX_XRES, cast(ushort)width);
		writeRegister(VBE_DISPI_INDEX_YRES, cast(ushort)height);
		writeRegister(VBE_DISPI_INDEX_BPP, bitDepth);
		writeRegister(VBE_DISPI_INDEX_VIRT_WIDTH, cast(ushort)width);
		writeRegister(VBE_DISPI_INDEX_VIRT_HEIGHT, cast(ushort)height);
		writeRegister(VBE_DISPI_INDEX_X_OFFSET, 0);
		writeRegister(VBE_DISPI_INDEX_Y_OFFSET, 0);
		writeRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_ENABLED | (useLinearFrameBuffer ? VBE_DISPI_LFB_ENABLED
				: 0) | (clearVideoMemory ? 0 : VBE_DISPI_NOCLEARMEM));
	}

	override void OnDisable() {
		writeRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);
	}

private:
	void writeRegister(ushort indexValue, ushort dataValue) {
		Out!ushort(VBE_DISPI_IOPORT_INDEX, indexValue);
		Out!ushort(VBE_DISPI_IOPORT_DATA, dataValue);
	}

	ushort readRegister(ushort indexValue) {
		Out!ushort(VBE_DISPI_IOPORT_INDEX, indexValue);
		return In!ushort(VBE_DISPI_IOPORT_DATA);
	}
}
