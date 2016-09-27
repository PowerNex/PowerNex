module IO.FS.IO.Console.Screen.VirtualConsoleScreen;

import IO.FS;
import IO.FS.IO.Console.Screen;
import Data.Address;
import Data.Color;
import Data.UTF;

abstract class VirtualConsoleScreen : FileNode {
public:
	this(size_t width, size_t height, FormattedChar clearChar) {
		super(NodePermissions.DefaultPermissions, 0);
		this.width = width;
		this.height = height;
		this.clearChar = clearChar;
		this.screen = new FormattedChar[width * height];
		for (size_t i = 0; i < screen.length; i++)
			screen[i] = clearChar;

		this.lineStarts = new size_t[height];
	}

	~this() {
		screen.destroy;
	}

	override bool Open() {
		if (inUse)
			return false;
		return inUse = true;
	}

	override void Close() {
		inUse = false;
	}

	/++
		TODO: Change how this works!
		XXX: Casting FormattedChar to a ubyte array is crazy!
	+/
	override ulong Read(ubyte[] buffer, ulong offset) {
		ubyte[] scr_b = cast(ubyte[])screen;

		size_t maxBytes = (buffer.length < scr_b.length) ? buffer.length : scr_b.length;

		for (size_t i = 0; i < maxBytes; i++)
			buffer[i] = scr_b[i];

		return maxBytes;
	}

	override ulong Write(ubyte[] buffer, ulong offset) {
		UTF8Range str = UTF8Range(buffer);

		if (active)
			UpdateChar(curX, curY); // Remove cursor rendering

		foreach (dchar ch; prepareData(str)) {
			switch (ch) {
			case '\n':
				curY++;
				curX = 0;
				break;
			case '\r':
				curX = 0;
				break;
			case '\b':
				if (curX)
					curX--;
				break;
			case '\t':
				size_t goal = (curX + 8) & ~7;
				if (goal > width)
					goal = width;
				for (; curX < goal; curX++) {
					screen[curY * width + curX] = clearChar;
					if (active)
						UpdateChar(curX, curY);
					curX++;
				}
				if (curX >= width) {
					curY++;
					curX = 0;
				}
				break;
			default:
				screen[curY * width + curX] = FormattedChar(ch, Color(255, 255, 0), Color(0, 0, 0), CharStyle.None);
				if (active)
					UpdateChar(curX, curY);
				curX++;
				if (curX >= width) {
					curY++;
					curX = 0;
				}
				break;
			}
		}
		if (active)
			UpdateCursor();
		return buffer.length;
	}

	void Clear() { //TODO:REMOVE
		clear();
	}

	@property bool Active() {
		return active;
	}

	@property bool Active(bool active) {
		if (active && !this.active) {
			for (size_t h = 0; h < height; h++)
				for (size_t w = 0; w < width; w++)
					UpdateChar(w, h);
			UpdateCursor();
		}
		this.active = active;
		return active;
	}

protected:
	FormattedChar[] screen;
	FormattedChar clearChar;
	size_t width;
	size_t height;
	size_t curX;
	size_t curY;

	// abstract void OnNewText(size_t startIdx, size_t length); //TODO: Use this instead of UpdateChar?
	abstract void OnScroll(size_t lineCount);
	abstract void UpdateCursor();
	abstract void UpdateChar(size_t x, size_t y);

private:
	bool inUse;
	bool active;

	size_t[] lineStarts;

	ref UTF8Range prepareData(ref UTF8Range str) {
		size_t charCount = curX;
		size_t lines;

		//size_t[] lineStarts = new size_t[height];
		size_t lsIdx;

		// Calc the number line

		size_t escapeCode;
		dchar escapeValue;
		size_t idx;
		foreach (dchar ch; str) {
			if (escapeCode) {
				if (escapeCode == 3) {
					if (ch != '[')
						goto parse;
				} else if (escapeCode == 2)
					escapeValue = ch;
				else {
					switch (ch) {
					case 'J':
						if (escapeValue == '2') {
							str.popFrontN(idx + 1);
							clear();
							return prepareData(str);
						}
						break;
					default:
						break;
					}
				}

				escapeCode--;
				idx++;
				continue;
			}
		parse:
			if (ch == '\x1B') {
				escapeCode = 3;
			} else if (ch == '\n') {
				lines++;
				charCount = 0;
				lsIdx = (lsIdx + 1) % height;
				lineStarts[lsIdx] = idx + 1; // Next char is the start of *new* the line
			} else if (ch == '\r') {
				charCount = 0;
				lineStarts[lsIdx] = idx + 1; // Update the lineStart on the current one
			} else if (ch == '\b') {
				if (charCount)
					charCount--;
			} else if (ch == '\t') {
				charCount = (charCount + 8) & ~7;
				if (charCount > width)
					charCount = width;
			} else
				charCount++;

			while (charCount >= width) {
				lines++;
				charCount -= width;
				lsIdx = (lsIdx + 1) % height;
				lineStarts[lsIdx] = idx + 1; // The current char is the start of *new* the line
			}

			idx++;
		}

		if (curY + lines >= height) {
			scroll(curY + lines - height + 1);

			// Skip the beginning of the data, that would never be shown on the screen.
			if (lines >= height) {
				if (lineStarts[(lsIdx + 1) % height] < str.length) {
					//XXX: Fix hack
					str.popFrontN(lineStarts[(lsIdx + 1) % height] + 1);
					//str = str[lineStarts[(lsIdx + 1) % height] + 1 .. $];
				} else
					str = UTF8Range([]);
			}

		}

		//lineStarts.destroy;
		return str;
	}

	void scroll(size_t lineCount) {
		if (lineCount > height)
			lineCount = height;

		if (active)
			UpdateChar(curX, curY); // Remove cursor rendering

		if (active)
			OnScroll(lineCount);

		size_t offset = FormattedChar.sizeof * lineCount * width;
		memmove(screen.ptr, (screen.VirtAddress + offset).Ptr, screen.length * FormattedChar.sizeof - offset);
		for (size_t i = screen.length - (lineCount * width); i < screen.length; i++)
			screen[i] = clearChar;

		ssize_t tmp = curY - lineCount;
		if (tmp < 0)
			curY = curX = 0;
		else
			curY = tmp;
	}

	void clear() {
		scroll(height);
		curX = curY = 0;
		if (active)
			UpdateCursor();
	}
}
