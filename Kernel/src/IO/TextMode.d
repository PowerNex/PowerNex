module IO.TextMode;

import IO.Port;
import Data.Util;
import Data.String;
import Data.TextBuffer;

enum Colors : ubyte {
	Black = 0,
	Blue = 1,
	Green = 2,
	Cyan = 3,
	Red = 4,
	Magenta = 5,
	Brown = 6,
	LightGrey = 7,
	DarkGrey = 8,
	LightBlue = 9,
	LightGreen = 10,
	LightCyan = 11,
	LightRed = 12,
	LightMagenta = 13,
	Yellow = 14,
	White = 15
}

struct Color {
	private ubyte color;

	this(Colors fg, Colors bg) {
		color = ((bg & 0xF) << 4) | (fg & 0xF);
	}

	@property Colors Foreground() {
		return cast(Colors)(color & 0xF);
	}

	@property Colors Foreground(Colors c) {
		color = (color & 0xF0) | (c & 0xF);
		return cast(Colors)(color & 0xF);
	}

	@property Colors Background() {
		return cast(Colors)((color >> 4) & 0xF);
	}

	@property Colors Background(Colors c) {
		color = ((c & 0xF) << 4) | (color & 0xF);
		return cast(Colors)((color >> 4) & 0xF);
	}

}

struct Screen(int w, int h) {
	private struct slot {
		char ch;
		Color color;
	}

	@disable this();

	this(Colors fg, Colors bg, long videoMemory) {
		this.screen = cast(slot[w * h]*)videoMemory;
		this.x = 0;
		this.y = 1;
		this.color = Color(fg, bg);
		this.enabled = true;
	}

	void Clear() {
		if (!enabled)
			return;
		foreach (ref slot slot; (*screen)[w .. $]) {
			slot.ch = ' ';
			slot.color = color;
		}
		x = 0;
		y = 1;
	}

	void Write(Slot[] slots) {
		if (!enabled)
			return;
		foreach (slot; slots)
			write(cast(char)slot.ch);
		MoveCursor();
	}

	void WriteStatus(Args...)(Args args) {
		if (!enabled)
			return;
		blockCursor++;
		ubyte oldX = x;
		ubyte oldY = y;
		Color oldColor = color;

		x = y = 0;
		color = Color(Colors.White, Colors.Red);
		Write(args);

		while (x < w - 1)
			write(' ');
		write(' ');

		x = oldX;
		y = oldY;
		color = oldColor;
		blockCursor--;
	}

	void MoveCursor() {
		if (!enabled)
			return;
		if (blockCursor > 0)
			return;
		ushort pos = y * w + x;
		Out!ubyte(0x3D4, 14);
		Out!ubyte(0x3D5, pos >> 8);
		Out!ubyte(0x3D4, 15);
		Out!ubyte(0x3D5, cast(ubyte)pos);
	}

	@property ref Color CurrentColor() {
		return color;
	}

	@property ref bool Enabled() {
		return enabled;
	}

private:
	slot[w * h]* screen;
	bool enabled;
	ubyte x, y;
	Color color;
	int blockCursor;

	void write(char ch) {
		if (ch == '\n') {
			y++;
			x = 0;
		} else if (ch == '\r')
			x = 0;
		else if (ch == '\b') {
			if (x)
				x--;
		} else if (ch == '\t') {
			uint goal = (x + 8) & ~7;
			for (; x < goal; x++)
				(*screen)[y * w + x] = slot(' ', color);
			if (x >= w) {
				y++;
				x %= w;
			}
		} else {
			(*screen)[y * w + x] = slot(ch, color);
			x++;

			if (x >= w) {
				y++;
				x = 0;
			}
		}

		if (y >= h) {
			for (int yy = 1; yy < h - 1; yy++)
				for (int xx = 0; xx < w; xx++)
					(*screen)[yy * w + xx] = (*screen)[(yy + 1) * w + xx];

			y--;
			for (int xx = 0; xx < w; xx++) {
				auto slot = &(*screen)[y * w + xx];
				slot.ch = ' ';
				slot.color = Color(Colors.Cyan, Colors.Black); //XXX: Stupid hack to fix colors while scrolling
			}
		}
		MoveCursor();
	}

	void Write(char ch) {
		if (!enabled)
			return;
		write(ch);
		MoveCursor();
	}

	void Write(in char[] str) {
		if (!enabled)
			return;
		foreach (char ch; str)
			write(ch);
		MoveCursor();
	}

	void Write(char* str) {
		if (!enabled)
			return;
		while (*str)
			write(*(str++));
		MoveCursor();
	}

	void WriteNumber(S = int)(S value, uint base) if (isNumber!S) {
		if (!enabled)
			return;
		char[S.sizeof * 8] buf;
		Write(itoa(value, buf, base));
	}

	void WriteEnum(T)(T value) if (is(T == enum)) {
		if (!enabled)
			return;
		foreach (i, e; EnumMembers!T)
			if (value == e) {
				Write(__traits(allMembers, T)[i]);
				return;
			}

		Write("cast(", T.stringof, ")", value);
	}

	void Write(Args...)(Args args) {
		if (!enabled)
			return;
		blockCursor++;
		foreach (arg; args) {
			alias T = Unqual!(typeof(arg));
			static if (is(T : const char[]))
				Write(arg);
			else static if (is(T == BinaryInt)) {
				Write("0b");
				WriteNumber(cast(ulong)arg, 2);
			} else static if (is(T : V*, V)) {
				Write("0x");
				WriteNumber(cast(ulong)arg, 16);
			} else static if (is(T == enum))
				WriteEnum(arg);
			else static if (is(T == bool))
				Write((arg) ? "true" : "false");
			else static if (is(T : char))
				write(arg);
			else static if (isNumber!T)
				WriteNumber(arg, 10);
			else
				Write("UNKNOWN TYPE '", T.stringof, "'");
		}
		blockCursor--;
		MoveCursor();
	}

	void Writeln(Args...)(Args args) {
		if (!enabled)
			return;
		blockCursor++;
		Write(args, '\n');
		blockCursor--;
		MoveCursor();
	}

}

__gshared Screen!(80, 25) GetScreen = Screen!(80, 25)(Colors.Cyan, Colors.Black, 0xFFFF_FFFF_800B_8000);
