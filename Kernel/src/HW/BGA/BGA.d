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
	VBOX_VENDOR = 0x80EE,
	VBOX_DEVICE = 0xBEEF,
	VBOX_OLDDEVICE = 0x7145,
}
enum {
	VBOX_ADDR = 0xE000_0000,
}

//dfmt on
import Data.TextBuffer;

void BootTTYToBGACB(size_t start, size_t end) {
	GetBGA.Write(GetBootTTY.Buffer[start .. end]);
}

class BGA {
public:
	this() {
		PCIDevice* bgaDevice = GetPCI.GetDevice(BGA_VENDOR, BGA_DEVICE);
		if (bgaDevice) {
			pixelData = PhysAddress(bgaDevice.bar0 & ~0b1111UL).Virtual.Ptr!Color;
			return;
		}
		bgaDevice = GetPCI.GetDevice(VBOX_VENDOR, VBOX_DEVICE);
		if (!bgaDevice)
			bgaDevice = GetPCI.GetDevice(VBOX_VENDOR, VBOX_OLDDEVICE);
		if (!bgaDevice)
			log.Fatal("BGA device not found!");
		pixelData = PhysAddress(VBOX_ADDR).Virtual.Ptr!Color;
	}

	int Version() {
		return readRegister(VBE_DISPI_INDEX_ID) - 0xB0C0;
	}

	void Init(PSF font) {
		import IO.TextMode : GetScreen;

		GetScreen.Enabled = false;
		GetBootTTY.OnChangedCallback = &BootTTYToBGACB;
		this.font = font;
		writeRegister(VBE_DISPI_INDEX_ID, VBE_DISPI_ID5);
		setVideoMode(1280, 720, VBE_DISPI_BPP_32, true, true);

		textMaxX = width / font.Width - 1;
		textMaxY = height / font.Height;
		Write(GetBootTTY.Buffer[0 .. GetBootTTY.Count]);
	}

	void Write(Slot[] slots) {
		foreach (Slot slot; slots)
			write(slot.ch, slot.fg, slot.bg);
	}

private:
	PSF font;
	ushort width;
	ushort height;
	Color* pixelData;
	ushort activeBank;

	int textX;
	int textY;
	int textMaxX;
	int textMaxY;
	/*
	void PrintString(wstring str, int x, int y, Color color, int scale = 1) {
		foreach (int idx, ch; str) {
			PrintChar(ch, x + (idx * font.Width + 1) * scale, y + 1 * scale, color / 10, scale);
			PrintChar(ch, x + idx * font.Width * scale, y, color, scale);
		}
	}*/

	void write(wchar ch, Color fg, Color bg) {
		if (ch == '\n') {
			textY++;
			textX = 0;
		} else if (ch == '\r')
			textX = 0;
		else if (ch == '\b') {
			if (textX)
				textX--;
		} else if (ch == '\t') {
			uint goal = (textX + 8) & ~7;
			for (; textX < goal; textX++)
				renderChar(' ', textX, textY, fg, bg);
			if (textX >= textMaxX) {
				textY++;
				textX %= textMaxX;
			}
		} else {
			renderChar(ch, textX, textY, fg, bg);
			textX++;

			if (textX >= textMaxX) {
				textY++;
				textX = 0;
			}
		}

		if (textY >= textMaxY) {
			memmove(pixelData, &(pixelData[width * font.Height]), width * height - (width * font.Height));

			textY--;
			putRect(0, height - font.Height, width, font.Height, bg);
		}
	}

	void renderChar(wchar ch, int x, int y, Color fg, Color bg) {
		x *= font.Width;
		y *= font.Height;
		ubyte[] charData = font.GetChar(ch);
		foreach (idxRow, ubyte row; charData)
			foreach (column; 0 .. 8)
				putRect(x + column, y + cast(int)idxRow, 1, 1, (row & (1 << (7 - column))) ? fg : bg);
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
