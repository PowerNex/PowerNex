module IO.Keyboard;

import CPU.IDT;
import Data.Register;
import IO.Port;

enum Modifiers : ubyte {
	None = 0,
	Control = 0x01,
	Alt = 0x02,
	AltGr = 0x04,
	LShift = 0x08,
	RShift = 0x10,
	CapsLock = 0x20,
	ScrollLock = 0x40,
	NumLock = 0x80,
	ReleasedMask = 0x80
}

struct KeyboardLayout {
	this(ubyte[] scancodes, ubyte[] shiftScancodes, ubyte[] controlMap, Modifiers modifiers) {
		for (int i = 0; i < scancodes.length && i < this.scancodes.length; i++)
			this.scancodes[i] = scancodes[i];
		for (int i = 0; i < shiftScancodes.length && i < this.shiftScancodes.length; i++)
			this.shiftScancodes[i] = shiftScancodes[i];
		for (int i = 0; i < controlMap.length && i < this.controlMap.length; i++)
			this.controlMap[i] = controlMap[i];
		this.modifiers = modifiers;
	}

	ubyte[128] scancodes;
	ubyte[128] shiftScancodes;

	ubyte[8] controlMap;

	Modifiers modifiers;
}

struct Keyboard {
public:
	static void Init() {
		uint IRQ1 = 33;
		IDT.Register(IRQ1, &onKey);
		layout = en_US;
	}

	static char Get() {
		if (start != end)
			return buffer[start++];
		else
			return '\0';
	}

private:
	__gshared KeyboardLayout layout;
	__gshared char[256] buffer;
	__gshared ubyte start, end;

	static void onKey(InterruptRegisters* regs) {
		ubyte scancode = In!ubyte(0x60);
		if (scancode & Modifiers.ReleasedMask) {
			for (int i = 0; i < 5; i++) {
				if (layout.controlMap[i] == (scancode & ~Modifiers.ReleasedMask)) {
					layout.modifiers &= ~(1 << i);
					return;
				}
			}
		} else {
			for (int i = 0; i < 8; i++) {
				if (layout.controlMap[i] == scancode) {
					if (layout.modifiers & 1 << i)
						layout.modifiers &= ~(1 << i);
					else
						layout.modifiers |= 1 << i;
					return;
				}
			}

			ubyte[] scancodes = layout.scancodes;
			if ((layout.modifiers & (Modifiers.LShift | Modifiers.RShift | Modifiers.CapsLock)) && !(layout.modifiers & Modifiers.Control))
				scancodes = layout.shiftScancodes;

			if (end != cast(ubyte)(start - 1))
				buffer[end++] = scancodes[scancode];
		}
	}

}

//dfmt off
private __gshared KeyboardLayout en_US = KeyboardLayout(
	//normal keys
	[
		/* first row - indices 0 to 14 */
		0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',

		/* second row - indices 15 to 28 */
		'\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n', //Enter key

		/* 29 = Control, 30 - 41: third row */
		0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',

		/* fourth row, indices 42 to 54, zeroes are shift-keys*/
		0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,

		'*',

		/* Special keys */

		0, //ALT - 56
		' ', // Space - 57
		0, //Caps lock - 58
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // F1 to F10 - 59 to 68
		0, //Num lock - 69
		0, //Scroll lock - 70
		0, //Home - 71
		0, //Up arrow - 72
		0, //Page up - 73
		'-',
		0, //Left arrow - 75
		0,
		0, //Right arrow -77
		'+',
		0, //End - 79
		0, //Dowm arrow - 80
		0, //Page down - 81
		0, //Insert - 82
		0, //Delete - 83
		0, 0, 0,
		0, //F11 - 87
		0, //F12 - 88
		0, //All others undefined
	],
	//caps
	[
		/* first row - indices 0 to 14 */
		0, 27, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b',

		/* second row - indices 15 to 28 */
		'\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', //Enter key

		/* 29 = Control, 30 - 41: third row */
		0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~',

		/* fourth row, indices 42 to 54, zeroes are shift-keys*/
		0, '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0,

		'*',

		/* Special keys */

		0, //ALT - 56
		' ', // Space - 57
		0, //Caps lock - 58
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // F1 to F10 - 59 to 68
		0, //Num lock - 69
		0, //Scroll lock - 70
		0, //Home - 71
		0, //Up arrow - 72
		0, //Page up - 73
		'-',
		0, //Left arrow - 75
		0,
		0, //Right arrow -77
		'+',
		0, //End - 79
		0, //Dowm arrow - 80
		0, //Page down - 81
		0, //Insert - 82
		0, //Delete - 83
		0, 0, 0,
		0, //F11 - 87
		0, //F12 - 88
		0, //All others undefined
	],

	// control_map
	[
		29, // Ctrl
		56, // Alt
		0,  // AltGr
		42, // left Shift
		54, // right Shift
		58, // Caps lock
		70, // Scroll lock
		69  // Num lock
	],

	//Set the initial status of all control keys to "not active"
	Modifiers.None
);
//dfmt on
