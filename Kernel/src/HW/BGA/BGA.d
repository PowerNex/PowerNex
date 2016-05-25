module HW.BGA.BGA;

import Data.Address;
import Data.Util;
import IO.Port;
import IO.Log;
import HW.BGA.PSF;
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

struct Color {
align(1):
	ubyte b;
	ubyte g;
	ubyte r;
	ubyte a;

	this(ubyte r, ubyte g, ubyte b) {
		this(r, g, b, 255);
	}

	this(ubyte r, ubyte g, ubyte b, ubyte a) {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}

	Color opBinary(string op)(ubyte rhs) {
		return Color(cast(ubyte)(r / rhs), cast(ubyte)(g / rhs), cast(ubyte)(b / rhs), a);
	}
}

static assert(Color.sizeof == uint.sizeof);

//dfmt off
__gshared Color[16] palette = [
	/* low brightness */
	Color(  0,  0,  0),
	Color(128,  0,  0),
	Color( 32,128,  0),
	Color(160, 64, 32),
	Color(  0, 32, 88),
	Color( 60,  0, 88),
	Color( 16,160,208),
	Color( 88, 88, 88),
	/* high brightness */
	Color( 32, 32, 32),
	Color(255, 64, 64),
	Color( 72,255, 64),
	Color(255,224, 60),
	Color( 48,128,255),
	Color(192, 48,255),
	Color( 72,224,255),
	Color(255,255,255),
];

enum : ushort
{
	BGA_VENDOR = 0x1234,
	BGA_DEVICE = 0x1111,
}
//dfmt on
import IO.TextMode : scr = GetScreen;

class BGA {
public:
	this() {
		PCIDevice* bgaDevice = GetPCI.GetDevice(BGA_VENDOR, BGA_DEVICE);
		if (!bgaDevice)
			log.Fatal("BGA device not found!");
		pixelData = PhysAddress(bgaDevice.bar0 & ~0b1111UL).Virtual.Ptr!Color;
	}

	int Version() {
		return readRegister(VBE_DISPI_INDEX_ID) - 0xB0C0;
	}

	void Init(PSF font) {
		scr.Enabled = false;
		this.font = font;
		writeRegister(VBE_DISPI_INDEX_ID, VBE_DISPI_ID5);
		setVideoMode(1280, 720, VBE_DISPI_BPP_32, true, true);

		foreach (y; 0 .. 2)
			foreach (x; 0 .. 8)
				putRect(cast(ushort)(width / 8 * x), cast(ushort)(height / 2 * y), cast(ushort)(width / 8),
						cast(ushort)(height / 2), palette[y * 8 + x] / 4);

		int scale = 4;

		int cw = width / 2;
		int ch = height / 2 - font.Height / 2;
		int diffH = font.Height / 2 * scale;
		PrintString("Hello World!", cw - (12 * font.Width * scale) / 2, ch - diffH, Color(255, 255, 0, 255), scale);
		PrintString("From PowerNex!", cw - (14 * font.Width * scale) / 2, ch + diffH, Color(0, 0, 255, 255), scale);
	}

private:
	PSF font;
	ushort width;
	ushort height;
	Color* pixelData;
	ushort activeBank;

	void PrintString(string str, int x, int y, Color color, int scale = 1) {
		foreach (int idx, ch; str) {
			PrintChar(ch, x + (idx * font.Width + 1) * scale, y + 1 * scale, color / 10, scale);
			PrintChar(ch, x + idx * font.Width * scale, y, color, scale);
		}
	}

	void PrintChar(char ch, int x, int y, Color color, int scale = 1) {
		ubyte[] charData = font.GetChar(ch);
		foreach (idxRow, ubyte row; charData)
			foreach (column; 0 .. 8) {
				if (!(row & (1 << (7 - column))))
					continue;

				putRect(x + column * scale, y + cast(int)idxRow * scale, scale, scale, color);
			}
	}

	void setBank(ushort id) {
		if (activeBank != id) {
			writeRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);
			writeRegister(VBE_DISPI_INDEX_BANK, id);
			writeRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_ENABLED);
			activeBank = id;
		}
	}

	void putPixel(int x, int y, Color color) {
		uint location = y * width + x;
		if (location >= width * height)
			return;
		pixelData[location] = color;
	}

	void putRect(int x, int y, int width, int height, Color color) {
		for (int xx = x; xx < x + width; xx++)
			for (int yy = y; yy < y + height; yy++)
				putPixel(xx, yy, color);
	}

	void putLine(int x0, int y0, int x1, int y1, Color color) {
		//Bresenham's line algorithm
		int steep = abs(y1 - y0) > abs(x1 - x0);
		short inc = -1;

		if (steep) {
			int tmp = x0;
			x0 = y0;
			y0 = tmp;

			tmp = x1;
			x1 = y1;
			y1 = tmp;
		}

		if (x0 > x1) {
			int tmp = x0;
			x0 = x1;
			x1 = tmp;

			tmp = y0;
			y0 = y1;
			y1 = tmp;
		}

		if (y0 < y1)
			inc = 1;

		int dx = cast(int)abs(x0 - x1);
		int dy = cast(int)abs(y1 - y0);
		int e = 0;
		int y = y0;
		int x = x0;

		for (; x <= x1; x++) {
			if (steep)
				putPixel(y, x, color);
			else
				putPixel(x, y, color);

			if ((e + dy) << 1 < dx)
				e += dy;
			else {
				y += inc;
				e += dy - dx;
			}
		}
	}

	void putCircle(int x0, int y0, int radius, Color color) {
		//Midpoint circle algorithm
		int x = radius;
		int y = 0;
		int radiusError = 1 - x;

		while (x >= y) {
			putPixel(x + x0, y + y0, color);
			putPixel(y + x0, x + y0, color);
			putPixel(-x + x0, y + y0, color);
			putPixel(-y + x0, x + y0, color);
			putPixel(-x + x0, -y + y0, color);
			putPixel(-y + x0, -x + y0, color);
			putPixel(x + x0, -y + y0, color);
			putPixel(y + x0, -x + y0, color);
			y++;
			if (radiusError < 0)
				radiusError += 2 * y + 1;
			else {
				x--;
				radiusError += 2 * (y - x) + 1;
			}
		}
	}

	void writeRegister(ushort indexValue, ushort dataValue) {
		Out!ushort(VBE_DISPI_IOPORT_INDEX, indexValue);
		Out!ushort(VBE_DISPI_IOPORT_DATA, dataValue);
	}

	ushort readRegister(ushort indexValue) {
		Out!ushort(VBE_DISPI_IOPORT_INDEX, indexValue);
		return In!ushort(VBE_DISPI_IOPORT_DATA);
	}

	void setVideoMode(ushort width, ushort height, ushort bitDepth, bool useLinearFrameBuffer, bool clearVideoMemory) {
		this.width = width;
		this.height = height;
		writeRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_DISABLED);
		writeRegister(VBE_DISPI_INDEX_XRES, width);
		writeRegister(VBE_DISPI_INDEX_YRES, height);
		writeRegister(VBE_DISPI_INDEX_BPP, bitDepth);
		writeRegister(VBE_DISPI_INDEX_VIRT_WIDTH, width);
		writeRegister(VBE_DISPI_INDEX_VIRT_HEIGHT, height);
		writeRegister(VBE_DISPI_INDEX_X_OFFSET, 0);
		writeRegister(VBE_DISPI_INDEX_Y_OFFSET, 0);
		writeRegister(VBE_DISPI_INDEX_ENABLE, VBE_DISPI_ENABLED | (useLinearFrameBuffer ? VBE_DISPI_LFB_ENABLED
				: 0) | (clearVideoMemory ? 0 : VBE_DISPI_NOCLEARMEM));
		//Out!ubyte(0x3c0, 0x20);
	}
}

BGA GetBGA() {
	import Data.Util : InplaceClass;

	__gshared ubyte[__traits(classInstanceSize, BGA)] data;
	__gshared BGA bga;

	if (!bga)
		bga = InplaceClass!BGA(data);
	return bga;
}
