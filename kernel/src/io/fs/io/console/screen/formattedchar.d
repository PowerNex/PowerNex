module io.fs.io.console.screen.formattedchar;

import data.color;

enum CharStyle {
	none,
	bold = 1 << 0,
	underline = 1 << 1,
	italic = 1 << 2,
	strikethru = 1 << 3
}

struct FormattedChar {
	dchar ch;
	Color fg;
	Color bg;
	CharStyle style;
}
