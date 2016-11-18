module io.fs.io.console.screen.virtualconsolescreen;

import io.fs;
import io.fs.io.console.screen;
import data.address;
import data.color;
import data.utf;

abstract class VirtualConsoleScreen : FileNode {
public:
	this(size_t width, size_t height, FormattedChar clearChar) {
		super(NodePermissions.defaultPermissions, 0);
		_width = width;
		_height = height;
		_clearChar = clearChar;
		_screen = new FormattedChar[width * height];
		for (size_t i = 0; i < _screen.length; i++)
			_screen[i] = _clearChar;

		_lineStarts = new size_t[height];
	}

	~this() {
		_screen.destroy;
	}

	override bool open() {
		if (_inUse)
			return false;
		return _inUse = true;
	}

	override void close() {
		_inUse = false;
	}

	/++
		TODO: Change how this works!
		XXX: Casting FormattedChar to a ubyte array is crazy!
	+/
	override ulong read(ubyte[] buffer, ulong offset) {
		ubyte[] scr_b = cast(ubyte[])_screen;

		size_t maxBytes = (buffer.length < scr_b.length) ? buffer.length : scr_b.length;

		for (size_t i = 0; i < maxBytes; i++)
			buffer[i] = scr_b[i];

		return maxBytes;
	}

	override ulong write(ubyte[] buffer, ulong offset) {
		UTF8Range str = UTF8Range(buffer);

		if (active)
			updateChar(_curX, _curY); // Remove cursor rendering

		foreach (dchar ch; _prepareData(str)) {
			switch (ch) {
			case '\n':
				_curY++;
				_curX = 0;
				break;
			case '\r':
				_curX = 0;
				break;
			case '\b':
				if (_curX)
					_curX--;
				break;
			case '\t':
				size_t goal = (_curX + 8) & ~7;
				if (goal > _width)
					goal = _width;
				for (; _curX < goal; _curX++) {
					_screen[_curY * _width + _curX] = _clearChar;
					if (active)
						updateChar(_curX, _curY);
				}
				if (_curX >= _width) {
					_curY++;
					_curX = 0;
				}
				break;
			default:
				_screen[_curY * _width + _curX] = FormattedChar(ch, Color(255, 255, 0), Color(0, 0, 0), CharStyle.none);
				if (active)
					updateChar(_curX, _curY);
				_curX++;
				if (_curX >= _width) {
					_curY++;
					_curX = 0;
				}
				break;
			}
		}
		if (active)
			updateCursor();
		return buffer.length;
	}

	void clear() { //TODO:REMOVE
		_clear();
	}

	@property bool active() {
		return _active;
	}

	@property bool active(bool active) {
		if (active && !_active) {
			for (size_t h = 0; h < _height; h++)
				for (size_t w = 0; w < _width; w++)
					updateChar(w, h);
			updateCursor();
		}
		_active = active;
		return _active;
	}

protected:
	FormattedChar[] _screen;
	FormattedChar _clearChar;
	size_t _width;
	size_t _height;
	size_t _curX;
	size_t _curY;

	// abstract void OnNewText(size_t startIdx, size_t length); //TODO: Use this instead of updateChar?
	abstract void onScroll(size_t lineCount);
	abstract void updateCursor();
	abstract void updateChar(size_t x, size_t y);

private:
	bool _inUse;
	bool _active;

	size_t[] _lineStarts;

	ref UTF8Range _prepareData(ref return UTF8Range str) {
		size_t charCount = _curX;
		size_t lines;

		//size_t[] _lineStarts = new size_t[_height];
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
							_clear();
							return _prepareData(str);
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
				lsIdx = (lsIdx + 1) % _height;
				_lineStarts[lsIdx] = idx + 1; // Next char is the start of *new* the line
			} else if (ch == '\r') {
				charCount = 0;
				_lineStarts[lsIdx] = idx + 1; // Update the lineStart on the current one
			} else if (ch == '\b') {
				if (charCount)
					charCount--;
			} else if (ch == '\t') {
				charCount = (charCount + 8) & ~7;
				if (charCount > _width)
					charCount = _width;
			} else
				charCount++;

			while (charCount >= _width) {
				lines++;
				charCount -= _width;
				lsIdx = (lsIdx + 1) % _height;
				_lineStarts[lsIdx] = idx + 1; // The current char is the start of *new* the line
			}

			idx++;
		}

		if (_curY + lines >= _height) {
			_scroll(_curY + lines - _height + 1);

			// Skip the beginning of the data, that would never be shown on the _screen.
			if (lines >= _height) {
				if (_lineStarts[(lsIdx + 1) % _height] < str.length) {
					//XXX: Fix hack
					str.popFrontN(_lineStarts[(lsIdx + 1) % _height] + 1);
					//str = str[_lineStarts[(lsIdx + 1) % _height] + 1 .. $];
				} else
					str = UTF8Range([]);
			}

		}

		//_lineStarts.destroy;
		return str;
	}

	void _scroll(size_t lineCount) {
		if (lineCount > _height)
			lineCount = _height;

		if (active)
			updateChar(_curX, _curY); // Remove cursor rendering

		if (active)
			onScroll(lineCount);

		size_t offset = FormattedChar.sizeof * lineCount * _width;
		memmove(_screen.ptr, (_screen.VirtAddress + offset).ptr, _screen.length * FormattedChar.sizeof - offset);
		for (size_t i = _screen.length - (lineCount * _width); i < _screen.length; i++)
			_screen[i] = _clearChar;

		ssize_t tmp = _curY - lineCount;
		if (tmp < 0)
			_curY = _curX = 0;
		else
			_curY = tmp;
	}

	void _clear() {
		_scroll(_height);
		_curX = _curY = 0;
		if (active)
			updateCursor();
	}
}
