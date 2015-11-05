module kmain;

enum Colors : ubyte {
	Black				= 0,
	Blue				 = 1,
	Green				= 2,
	Cyan				 = 3,
	Red					= 4,
	Magenta			= 5,
	Brown				= 6,
	LightGrey		= 7,
	DarkGrey		 = 8,
	LightBlue		= 9,
	LightGreen	 = 10,
	LightCyan		= 11,
	LightRed		 = 12,
	LightMagenta = 13,
	LightBrown	 = 14,
	White				= 15
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

struct vid_slot {
	char ch;
	Color color;
}

struct Screen(int w, int h) {
	vid_slot[w*h] * screen;
	ubyte x, y;

	this(typeof(screen) screen) {
		this.screen = screen;
		this.x = 0;
		this.y = 0;
		Clear();
	}

	void Clear() {
		foreach (ref vid_slot slot; *screen) {
			slot.ch = ' ';
			slot.color.Foreground = Colors.Cyan;
			slot.color.Background = Colors.Black;
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
			for (int xx = 0; xx < w; x++)
				(*screen)[y*w + xx].ch = ' ';
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

enum isByte(T)  = is(T == byte)  || is(T == ubyte);
enum isShort(T) = is(T == short) || is(T == ushort);
enum isInt(T)   = is(T == int)   || is(T == uint);
enum isLong(T)  = is(T == long)  || is(T == ulong);

 T In(T = ubyte)(ushort port) {
	T ret;
	asm {
		mov DX, port;
	}

	static if (isByte!T) {
		asm {
			in AL, DX;
			mov ret, AL;
		}
	} else static if (isShort!T) {
		asm {
			in AX, DX;
			mov ret, AX;
		}
	} else static if (isInt!T) {
		asm {
			in EAX, DX;
			mov ret, EAX;
		}
	}

	return ret;
}

void Out(T = ubyte)(ushort port, uint data) {
	asm {
		mov EAX, data;
		mov DX, port;
	}

	static if (isByte!T) {
		asm {
			out DX, AL;
		}
	} else static if (isShort!T) {
		asm {
			out DX, AX;
		}
	} else static if (isInt!T) {
		asm {
			out DX, EAX;
		}
	}
}

void main() {
	auto vid = Screen!(80, 25)(cast(vid_slot[25*80] *)0xB8000);
	vid.Clear();
	vid.Print("Hello World!");
	asm {
		forever:
			hlt;
			jmp forever;
	}
}
