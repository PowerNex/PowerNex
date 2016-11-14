module io.fs.io.console.screen.virtualconsolescreentextmode;

import io.fs;
import io.fs.io.console.screen;

import data.color;

import data.address;

final class VirtualConsoleScreenTextMode : VirtualConsoleScreen {
public:
	this() {
		super(80, 25, FormattedChar(' ', Color(0xFF, 0xFF, 0xFF), Color(0x00, 0x00, 0x00), CharStyle.none));
		_slots = VirtAddress(0xFFFF_FFFF_800B_8000).ptr!Slot[0 .. _width * _height];
	}

protected:
	override void onScroll(size_t lineCount) {
		size_t offset = Slot.sizeof * lineCount * _width;
		memmove(_slots.ptr, (_slots.VirtAddress + offset).ptr, _slots.length * Slot.sizeof - offset);
		for (size_t i = _slots.length - (lineCount * _width); i < _slots.length; i++)
			_slots[i] = _toSlot(_clearChar);
	}

	override void updateCursor() {
		import io.port;

		ushort pos = cast(ushort)(_curY * _width + _curX);
		outp!ubyte(0x3D4, 14);
		outp!ubyte(0x3D5, pos >> 8);
		outp!ubyte(0x3D4, 15);
		outp!ubyte(0x3D5, cast(ubyte)pos);
	}

	override void updateChar(size_t x, size_t y) {
		FormattedChar fc = _screen[y * _width + x];
		_slots[y * _width + x] = _toSlot(fc);
	}

private:
	struct Slot {
		char ch;
		CharColor color;
	}

	Slot[] _slots;

	TMColor _findNearest(Color c) {
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

	Slot _toSlot(FormattedChar fc) {
		return Slot(cast(char)fc.ch, CharColor(_findNearest(fc.fg), _findNearest(fc.bg)));
	}
}

private {
	enum TMColor : ubyte {
		black = 0,
		blue = 1,
		green = 2,
		cyan = 3,
		red = 4,
		magenta = 5,
		brown = 6,
		lightGray = 7,
		darkGray = 8,
		lightBlue = 9,
		lightGreen = 10,
		lightCyan = 11,
		lightRed = 12,
		lightMagenta = 13,
		yellow = 14,
		white = 15
	}

	//dfmt off
	immutable Color[/*TMColor*/] TMColorPalette = [
		/*TMColor.black: */Color(0, 0, 0),
		/*TMColor.blue: */Color(0, 0, 170),
		/*TMColor.green: */Color(0, 170, 0),
		/*TMColor.cyan: */Color(0, 170, 170),
		/*TMColor.red: */Color(170, 0, 0),
		/*TMColor.magenta: */Color(170, 0, 170),
		/*TMColor.brown: */Color(170, 85, 0),
		/*TMColor.lightGray: */Color(170, 170, 170),
		/*TMColor.darkGray: */Color(85, 85, 85),
		/*TMColor.lightBlue: */Color(85, 85, 255),
		/*TMColor.lightGreen: */Color(85, 255, 85),
		/*TMColor.lightCyan: */Color(85, 255, 255),
		/*TMColor.lightRed: */Color(255, 85, 85),
		/*TMColor.lightMagenta: */Color(255, 85, 255),
		/*TMColor.yellow: */Color(255, 255, 85),
		/*TMColor.white: */Color(255, 255, 255)
	];
	//dfmt on

	struct CharColor {
		private ubyte _color;

		this(TMColor fg, TMColor bg) {
			_color = ((bg & 0xF) << 4) | (fg & 0xF);
		}

		@property TMColor foreground() {
			return cast(TMColor)(_color & 0xF);
		}

		@property TMColor foreground(TMColor c) {
			_color = (_color & 0xF0) | (c & 0xF);
			return cast(TMColor)(_color & 0xF);
		}

		@property TMColor background() {
			return cast(TMColor)((_color >> 4) & 0xF);
		}

		@property TMColor background(TMColor c) {
			_color = ((c & 0xF) << 4) | (_color & 0xF);
			return cast(TMColor)((_color >> 4) & 0xF);
		}
	}
}
