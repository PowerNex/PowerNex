module IO.FS.IO.Console.Screen.VirtualConsoleScreenTextMode;

import IO.FS;
import IO.FS.IO.Console.Screen;

import Data.Color;

import Data.Address;

final class VirtualConsoleScreenTextMode : VirtualConsoleScreen {
public:
	this() {
		super(80, 25, FormattedChar(' ', Color(0xFF, 0xFF, 0xFF), Color(0x00, 0x00, 0x00), CharStyle.None));
		slots = VirtAddress(0xFFFF_FFFF_800B_8000).Ptr!Slot[0 .. width * height];
	}

protected:
	override void OnScroll(size_t lineCount) {
		size_t offset = Slot.sizeof * lineCount * width;
		memmove(slots.ptr, (slots.VirtAddress + offset).Ptr, slots.length * Slot.sizeof - offset);
		for (size_t i = slots.length - (lineCount * width); i < slots.length; i++)
			slots[i] = toSlot(clearChar);
	}

	override void UpdateCursor() {
		import IO.Port;

		ushort pos = cast(ushort)(curY * width + curX);
		Out!ubyte(0x3D4, 14);
		Out!ubyte(0x3D5, pos >> 8);
		Out!ubyte(0x3D4, 15);
		Out!ubyte(0x3D5, cast(ubyte)pos);
	}

	override void UpdateChar(size_t x, size_t y) {
		FormattedChar fc = screen[y * width + x];
		slots[y * width + x] = toSlot(fc);
	}

private:
	struct Slot {
		char ch;
		CharColor color;
	}

	Slot[] slots;

	TMColor findNearest(Color c) {
		TMColor tc;
		ulong dif = ulong.max;

		foreach (tmColor, color; TMColorPalette) {
			const ulong d = ((c.r - color.r) ^^ 2 + (c.g - color.g) ^^ 2 + (c.b - color.b) ^^ 2);
			if (d <= dif) {
				tc = cast(TMColor)tmColor;
				dif = d;
			}
		}

		return tc;
	}

	Slot toSlot(FormattedChar fc) {
		return Slot(cast(char)fc.ch, CharColor(findNearest(fc.fg), findNearest(fc.bg)));
	}
}

private {
	enum TMColor : ubyte {
		Black = 0,
		Blue = 1,
		Green = 2,
		Cyan = 3,
		Red = 4,
		Magenta = 5,
		Brown = 6,
		LightGray = 7,
		DarkGray = 8,
		LightBlue = 9,
		LightGreen = 10,
		LightCyan = 11,
		LightRed = 12,
		LightMagenta = 13,
		Yellow = 14,
		White = 15
	}

	//dfmt off
	immutable Color[/*TMColor*/] TMColorPalette = [
		/*TMColor.Black: */Color(0, 0, 0),
		/*TMColor.Blue: */Color(0, 0, 170),
		/*TMColor.Green: */Color(0, 170, 0),
		/*TMColor.Cyan: */Color(0, 170, 170),
		/*TMColor.Red: */Color(170, 0, 0),
		/*TMColor.Magenta: */Color(170, 0, 170),
		/*TMColor.Brown: */Color(170, 85, 0),
		/*TMColor.LightGray: */Color(170, 170, 170),
		/*TMColor.DarkGray: */Color(85, 85, 85),
		/*TMColor.LightBlue: */Color(85, 85, 255),
		/*TMColor.LightGreen: */Color(85, 255, 85),
		/*TMColor.LightCyan: */Color(85, 255, 255),
		/*TMColor.LightRed: */Color(255, 85, 85),
		/*TMColor.LightMagenta: */Color(255, 85, 255),
		/*TMColor.Yellow: */Color(255, 255, 85),
		/*TMColor.White: */Color(255, 255, 255)
	];
	//dfmt on

	struct CharColor {
		private ubyte color;

		this(TMColor fg, TMColor bg) {
			color = ((bg & 0xF) << 4) | (fg & 0xF);
		}

		@property TMColor Foreground() {
			return cast(TMColor)(color & 0xF);
		}

		@property TMColor Foreground(TMColor c) {
			color = (color & 0xF0) | (c & 0xF);
			return cast(TMColor)(color & 0xF);
		}

		@property TMColor Background() {
			return cast(TMColor)((color >> 4) & 0xF);
		}

		@property TMColor Background(TMColor c) {
			color = ((c & 0xF) << 4) | (color & 0xF);
			return cast(TMColor)((color >> 4) & 0xF);
		}
	}
}
