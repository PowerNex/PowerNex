module io.textmode;

import io.port;
import data.util;
import data.string;

enum Colors : ubyte {
	Black        = 0,
	Blue         = 1,
	Green        = 2,
	Cyan         = 3,
	Red          = 4,
	Magenta      = 5,
	Brown        = 6,
	LightGrey    = 7,
	DarkGrey     = 8,
	LightBlue    = 9,
	LightGreen   = 10,
	LightCyan    = 11,
	LightRed     = 12,
	LightMagenta = 13,
	LightBrown   = 14,
	White        = 15
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

	slot[w*h] * screen;
	ubyte x, y;
	Color color;

	@disable this();

	this(Colors fg, Colors bg) {
		this.screen = cast(slot[25*80] *)0xB8000;
		this.x = 0;
		this.y = 0;
		this.color = Color(fg, bg);
	}

	void Clear() {
		foreach (ref slot slot; *screen) {
			slot.ch = ' ';
			slot.color = color;
		}
		x = y = 0;
	}

	void Write(char ch) {
		if (ch == '\n') {
			y++;
			x = 0;
		} else if (ch == '\r') {
			x = 0;
		} else if (ch == '\b') {
			if (x)
				x--;
		} else if (ch == '\t') {
			x = cast(ubyte)(x + 8) & ~7;
		} else {
			(*screen)[y*w + x].ch = ch;
			(*screen)[y*w + x].color = color;
			x++;

			if (x >= w) {
				y++;
				x = 0;
			}
		}

		if (y >= h) {
			for (int yy = 0; yy < h - 1; yy++)
				for (int xx = 0; xx < w; x++) {
					(*screen)[yy*w + xx] = (*screen)[yy*w + xx + w];
				}

			y--;
			for (int x = 0; x < w; x++) {
				auto slot = &(*screen)[y*w + x];
				slot.ch = ' ';
				slot.color = color;
			}
		}
		MoveCursor();
	}

	void Write(in char[] str) {
		foreach (char ch; str)
			Write(ch);
	}

	void Write(char * str) {
		while (*str)
			Write(*(str++));
	}

	void WriteNumber(S = int)(S value, uint base) if(isNumber!S) {
		ubyte[S.sizeof * 8] buf;
		auto start = itoa(value, buf.ptr, buf.length, base);
		for (size_t i = start; i < buf.length; i++)
			Write(buf[i]);
	}

	void Write(Args...)(Args args) {
		foreach(arg; args) {
			alias T = Unqual!(typeof(arg));
			static if (is(T : const char[]))
				Write(arg);
			else static if (is(T : char))
				Write(arg);
			else static if (isNumber!T)
				WriteNumber(arg, 10);
			else
				Write("UNKNOWN TYPE '", T.stringof, "'");
		}
	}

	void Writeln(Args...)(Args arg) {
		Write(arg, '\n');
	}

	void MoveCursor() {
		ushort pos = y * w + x;
		Out!ubyte(0x3D4, 14);
		Out!ubyte(0x3D5, pos >> 8);
		Out!ubyte(0x3D4, 15);
		Out!ubyte(0x3D5, cast(ubyte)pos);
	}
}

__gshared Screen!(80, 25) GetScreen = Screen!(80, 25)(Colors.Cyan, Colors.Black);
