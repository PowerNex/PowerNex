/**
 * A interface to manage the VGA mode called text-mode.
 * (Could also be called CGA)
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.io.vga;

import stl.trait;
import stl.spinlock;

///
enum CGAColor {
	black = 0, ///
	blue = 1, ///
	green = 2, ///
	cyan = 3, ///
	red = 4, ///
	magenta = 5, ///
	brown = 6, ///
	lightGrey = 7, ///
	darkGrey = 8, ///
	lightBlue = 9, ///
	lightGreen = 10, ///
	lightCyan = 11, ///
	lightRed = 12, ///
	lightMagenta = 13, ///
	yellow = 14, ///
	white = 15 ///
}

///
@safe struct CGASlotColor {
	private ubyte _color;

	///
	this(CGAColor fg, CGAColor bg) {
		_color = ((bg & 0xF) << 4) | (fg & 0xF);
	}

	///
	@property CGAColor foreground() {
		return cast(CGAColor)(_color & 0xF);
	}

	///
	@property CGAColor foreground(CGAColor c) {
		_color = (_color & 0xF0) | (c & 0xF);
		return cast(CGAColor)(_color & 0xF);
	}

	///
	@property CGAColor background() {
		return cast(CGAColor)((_color >> 4) & 0xF);
	}

	///
	@property CGAColor background(CGAColor c) {
		_color = ((c & 0xF) << 4) | (_color & 0xF);
		return cast(CGAColor)((_color >> 4) & 0xF);
	}
}

///
@safe struct CGAVideoSlot {
	char ch;
	CGASlotColor color;
}

///
@trusted static struct VGA {
public static:
	void init(ubyte x = 0, ubyte y = 0) {
		_screen = cast(CGAVideoSlot[80 * 25]*)0xB8000;
		_x = x;
		_y = y;
		_color = CGASlotColor(CGAColor.yellow, CGAColor.black);
	}
	///
	void clear() @trusted {
		_memLock.lock();

		foreach (ref slot; *_screen)
			slot = CGAVideoSlot('\x02', _color);
		_x = _y = 0;
		_moveCursor();

		_memLock.unlock();
	}

	///
	void writeln(Args...)(Args args) {
		write(args, "\n");
	}

	///
	void write(Args...)(Args args) {
		import stl.address : VirtAddress, PhysAddress, PhysAddress32;
		import stl.trait : Unqual, isNumber, isFloating;
		import stl.text : BinaryInt, HexInt;

		_memLock.lock();

		foreach (arg; args) {
			alias T = Unqual!(typeof(arg));
			static if (is(T : const char[]))
				_write(arg);
			else static if (is(T == BinaryInt)) {
				_write("0b");
				_writeNumber(arg.number, 2);
			} else static if (is(T == HexInt)) {
				_write("0x");
				_writeNumber(arg.number, 16);
			} else static if (is(T : V*, V))
				_writePointer(cast(ulong)arg);
			else static if (is(T == VirtAddress) || is(T == PhysAddress) || is(T == PhysAddress32))
				_writePointer(arg.num);
			else static if (is(T == enum))
				_writeEnum(arg);
			else static if (is(T == bool))
				_write((arg) ? "true" : "false");
			else static if (is(T : char))
				_write(arg);
			else static if (isNumber!T)
				_writeNumber(arg, 10);
			else static if (isFloating!T)
				_writeFloating(cast(double)arg, 10);
			else
				_write(arg.toString);
		}

		_moveCursor();
		_memLock.unlock();
	}

	///
	@property CGASlotColor color() {
		return _color;
	}

	///
	@property CGASlotColor color(CGASlotColor color) {
		_color = color;
		return _color;
	}

	@property ref ubyte x() {
		return _x;
	}

	@property ref ubyte y() {
		return _y;
	}

private static:
	__gshared CGAVideoSlot[80 * 25]* _screen;
	__gshared ubyte _x;
	__gshared ubyte _y;
	__gshared CGASlotColor _color;
	__gshared int _blockCursor;
	__gshared SpinLock _memLock;

	void _moveCursor() {
		import stl.arch.amd64.ioport : outp;

		if (_blockCursor > 0)
			return;
		ushort pos = _y * 80 + _x;
		outp!ubyte(0x3D4, 14);
		outp!ubyte(0x3D5, pos >> 8);
		outp!ubyte(0x3D4, 15);
		outp!ubyte(0x3D5, cast(ubyte)pos);
	}

	void _write(char ch) {
		if (ch == '\t') {
			uint goal = (_x + 8) & ~7;
			int count = goal - _x;
			foreach (i; 0 .. goal - _x)
				_write(' ');

			return;
		}

		if (_x >= 80) {
			_y++;
			_x = 0;
		}
		if (_y >= 25) {
			import stl.address : memmove;

			memmove(&(*_screen)[0], &(*_screen)[80], 80 * 24 * CGAVideoSlot.sizeof);

			_y--;
			for (int xx = 0; xx < 80; xx++) {
				auto slot = &(*_screen)[_y * 80 + xx];
				slot.ch = ' ';
				slot.color = CGASlotColor(CGAColor.cyan, CGAColor.black); //XXX: Stupid hack to fix colors while scrolling
			}
		}

		if (ch == '\n') {
			_y++;
			_x = 0;
		} else if (ch == '\r')
			_x = 0;
		else if (ch == '\b') {
			if (_x)
				_x--;
		} else {
			(*_screen)[_y * 80 + _x] = CGAVideoSlot(ch, _color);
			_x++;
		}

		// Uncomment this for prettier mouse movement!
		// _moveCursor();
	}

	void _write(in char[] str) {
		foreach (char ch; str)
			_write(ch);
	}

	void _write(char* str) @trusted {
		while (*str)
			_write(*(str++));
	}

	void _writeNumber(S = long)(S value, uint base) if (isNumber!S) {
		import stl.text : itoa;

		char[S.sizeof * 8] buf;
		_write(itoa(value, buf, base));
	}

	void _writePointer(ulong value) {
		import stl.text : itoa;

		char[ulong.sizeof * 8] buf;
		_write("0x");
		string val = itoa(value, buf, 16, 16);
		_write(val[0 .. 8]);
		_write('_');
		_write(val[8 .. 16]);
	}

	void _writeFloating(double value, uint base) {
		import stl.text : dtoa;

		char[double.sizeof * 8] buf;
		_write(dtoa(value, buf, base));
	}

	void _writeEnum(T)(T value) if (is(T == enum)) {
		import stl.trait : enumMembers;

		foreach (i, e; enumMembers!T)
			if (value == e) {
				_write(__traits(allMembers, T)[i]);
				return;
			}

		_write("cast(");
		_write(T.stringof);
		_write(")");
		_writeNumber(cast(int)value, 10);
	}
}
