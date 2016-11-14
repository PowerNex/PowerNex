module IO.FS.IO.Console.Screen.FormattedChar;

import Data.Color;

enum CharStyle {
	None,
	Bold = 1 << 0,
	Underline = 1 << 1,
	Italic = 1 << 2,
	Strikethru = 1 << 3
}

struct FormattedChar {
	dchar ch;
	Color fg;
	Color bg;
	CharStyle style;
}
