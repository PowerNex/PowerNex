module io.textmode;

import io.port;
import data.util;
import data.string_;
import data.textbuffer;

enum Colors : ubyte {
	black = 0,
	blue = 1,
	green = 2,
	cyan = 3,
	red = 4,
	magenta = 5,
	brown = 6,
	lightGrey = 7,
	darkGrey = 8,
	lightBlue = 9,
	lightGreen = 10,
	lightCyan = 11,
	lightRed = 12,
	lightMagenta = 13,
	yellow = 14,
	white = 15
}

struct Color {
	private ubyte _color;

	this(Colors fg, Colors bg) {
		_color = ((bg & 0xF) << 4) | (fg & 0xF);
	}

	@property Colors foreground() {
		return cast(Colors)(_color & 0xF);
	}

	@property Colors foreground(Colors c) {
		_color = (_color & 0xF0) | (c & 0xF);
		return cast(Colors)(_color & 0xF);
	}

	@property Colors background() {
		return cast(Colors)((_color >> 4) & 0xF);
	}

	@property Colors background(Colors c) {
		_color = ((c & 0xF) << 4) | (_color & 0xF);
		return cast(Colors)((_color >> 4) & 0xF);
	}

}

struct Screen(int w, int h) {
	private struct VideoSlot {
	align(1):
		char ch;
		Color color;
	}

	@disable this();

	this(Colors fg, Colors bg, long videoMemory) {
		_screen = cast(VideoSlot[w * h]*)videoMemory;
		_x = 0;
		_y = 0;
		_color = Color(fg, bg);
		_enabled = true;
	}

	void clear() {
		if (!_enabled)
			return;

		foreach (ref VideoSlot slot; (*_screen)[w .. $]) {
			slot.ch = ' ';
			slot.color = _color;
		}
		_x = 0;
		_y = 0;
	}

	void write(Slot[] slots) {
		if (!_enabled)
			return;
		foreach (slot; slots) {
			Colors fg, bg;
			import data.color : RGB = Color;

			Colors toColors(RGB rgb) {
				Colors c;
				if (rgb.r / 128)
					c |= Colors.red;
				if (rgb.g / 128)
					c |= Colors.green;
				if (rgb.b / 128)
					c |= Colors.blue;

				size_t total = rgb.r + rgb.g + rgb.b;
				if (total / 128 * 3)
					c |= Colors.darkGrey; // Aka bright-bit

				return c;
			}

			_color = Color(toColors(slot.fg), toColors(slot.bg));
			_write(cast(char)slot.ch);
		}
		_moveCursor();
	}

	void _moveCursor() {
		if (!_enabled)
			return;
		if (_blockCursor > 0)
			return;
		ushort pos = _y * w + _x;
		outp!ubyte(0x3D4, 14);
		outp!ubyte(0x3D5, pos >> 8);
		outp!ubyte(0x3D4, 15);
		outp!ubyte(0x3D5, cast(ubyte)pos);
	}

	@property ref Color currentColor() {
		return _color;
	}

	@property ref bool enabled() {
		return _enabled;
	}

private:
	VideoSlot[w * h]* _screen;
	bool _enabled;
	ubyte _x;
	ubyte _y;
	Color _color;
	int _blockCursor;

	void _realWrite(char ch) {
		if (ch == '\n') {
			_y++;
			_x = 0;
		} else if (ch == '\r')
			_x = 0;
		else if (ch == '\b') {
			if (_x)
				_x--;
		} else if (ch == '\t') {
			uint goal = (_x + 8) & ~7;
			for (; _x < goal; _x++)
				(*_screen)[_y * w + _x] = VideoSlot(' ', _color);
			if (_x >= w) {
				_y++;
				_x %= w;
			}
		} else {
			(*_screen)[_y * w + _x] = VideoSlot(ch, _color);
			_x++;

			if (_x >= w) {
				_y++;
				_x = 0;
			}
		}

		if (_y >= h) {
			for (int yy = 0; yy < h - 1; yy++)
				for (int xx = 0; xx < w; xx++)
					(*_screen)[yy * w + xx] = (*_screen)[(yy + 1) * w + xx];

			_y--;
			for (int xx = 0; xx < w; xx++) {
				auto slot = &(*_screen)[_y * w + xx];
				slot.ch = ' ';
				slot.color = Color(Colors.cyan, Colors.black); //XXX: Stupid hack to fix colors while scrolling
			}
		}
		_moveCursor();
	}

	void _write(char ch) {
		if (!_enabled)
			return;
		_realWrite(ch);
		_moveCursor();
	}

	void _write(in char[] str) {
		if (!_enabled)
			return;
		foreach (char ch; str)
			_realWrite(ch);
		_moveCursor();
	}

	void _write(char* str) {
		if (!_enabled)
			return;
		while (*str)
			_realWrite(*(str++));
		_moveCursor();
	}

	void _writeNumber(S = int)(S value, uint base) if (isNumber!S) {
		if (!_enabled)
			return;
		char[S.sizeof * 8] buf;
		_write(itoa(value, buf, base));
	}

	void _writeEnum(T)(T value) if (is(T == enum)) {
		if (!_enabled)
			return;
		foreach (i, e; enumMembers!T)
			if (value == e) {
				_write(__traits(allMembers, T)[i]);
				return;
			}

		_write("cast(", T.stringof, ")", value);
	}

	void _write(Args...)(Args args) {
		if (!_enabled)
			return;
		_blockCursor++;
		foreach (arg; args) {
			alias T = Unqual!(typeof(arg));
			static if (is(T : const char[]))
				_write(arg);
			else static if (is(T == BinaryInt)) {
				_write("0b");
				_writeNumber(cast(ulong)arg, 2);
			} else static if (is(T : V*, V)) {
				_write("0x");
				_writeNumber(cast(ulong)arg, 16);
			} else static if (is(T == enum))
				_writeEnum(arg);
			else static if (is(T == bool))
				_write((arg) ? "true" : "false");
			else static if (is(T : char))
				write(arg);
			else static if (isNumber!T)
				_writeNumber(arg, 10);
			else
				_write("UNKNOWN TYPE '", T.stringof, "'");
		}
		_blockCursor--;
		_moveCursor();
	}

	void _writeln(Args...)(Args args) {
		if (!_enabled)
			return;
		_blockCursor++;
		_write(args, '\n');
		_blockCursor--;
		_moveCursor();
	}

}

__gshared Screen!(80, 25) getScreen = Screen!(80, 25)(Colors.cyan, Colors.black, 0xFFFF_FFFF_800B_8000);
