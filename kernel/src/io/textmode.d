module io.textmode;

import io.port;

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
	Color defaultColor;

	this(Colors fg, Colors bg) {
		this.screen = cast(slot[25*80] *)0xB8000;
		this.x = 0;
		this.y = 0;
		this.defaultColor.Foreground = fg;
		this.defaultColor.Background = bg;
		Clear();
	}

	void Clear() {
		foreach (ref slot slot; *screen) {
			slot.ch = ' ';
			slot.color = defaultColor;
		}
		x = y = 0;
	}

	void Print(char ch) {
		if (ch == '\n') {
			y++;
			x = 0;
		} else if (ch == '\r') {
			x = 0;
		} else if (ch == '\b') {
			if (x)
				x--;
		} else {
			(*screen)[y*w + x].ch = ch;
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
				slot.color = defaultColor;
			}
		}
		MoveCursor();
	}

	void Print(string str) {
		foreach (char ch; str)
			Print(ch);
	}

	void MoveCursor() {
		ushort pos = y * w + x;
		Out!ubyte(0x3D4, 14);
		Out!ubyte(0x3D5, pos >> 8);
		Out!ubyte(0x3D4, 15);
		Out!ubyte(0x3D5, cast(ubyte)pos);
	}
}
