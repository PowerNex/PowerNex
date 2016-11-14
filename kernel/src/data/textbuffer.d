module data.textbuffer;

import data.color;
import data.string_;
import data.util;

enum SlotFlags : ushort {
	nothing,
	blinking = 1 << 0,
	//underline = 1 << 1,
	//bold = 1 << 2,
	shadow = 1 << 3,
	invertedColors = 1 << 4,
	flipX = 1 << 5,
	flipY = 1 << 6,

	unknown = 1 << 15,
}

struct Slot {
	wchar ch;
	Color fg;
	Color bg;
	SlotFlags flags;
	private uint _dummy;
}

static assert(Slot.sizeof == 16);

class TextBuffer {
public:
	alias OnChangedCallbackType = void function(size_t start, size_t end);

	this(Slot[] buffer) {
		_buffer = buffer;
		_otherBuffer = true;

		_defaultFG = Color(0, 255, 255);
		_defaultBG = Color(0, 0x22, 0x22);
	}

	this(size_t size) {
		_buffer = new Slot[size];
		_otherBuffer = false;

		_defaultFG = Color(0, 255, 255);
		_defaultBG = Color(0, 0x22, 0x22);
	}

	~this() {
		if (!_otherBuffer)
			_buffer.destroy;
	}

	void write(Args...)(Args args) {
		import data.address;

		size_t startPos = _count;
		Color fg = _defaultFG;
		Color bg = _defaultBG;
		SlotFlags flags = _defaultFlags;
		foreach (arg; args) {
			alias T = Unqual!(typeof(arg));
			static if (is(T : const char[]))
				_write(arg, fg, bg, flags);
			else static if (is(T == BinaryInt)) {
				_write("0b", fg, bg, flags);
				_writeNumber(arg.num, 2, fg, bg, flags);
			} else static if (is(T : V*, V)) {
				_write("0x", fg, bg, flags);
				_writeNumber(cast(ulong)arg, 16, fg, bg, flags);
			} else static if (is(T == VirtAddress) || is(T == PhysAddress) || is(T == PhysAddress32)) {
				_write("0x", fg, bg, flags);
				_writeNumber(cast(ulong)arg.num, 16, fg, bg, flags);
			} else static if (is(T == enum))
				_writeEnum(arg, fg, bg, flags);
			else static if (is(T == bool))
				_write((arg) ? "true" : "false", fg, bg, flags);
			else static if (is(T : char))
				_write(arg, fg, bg, flags);
			else static if (isNumber!T)
				_writeNumber(arg, 10, fg, bg, flags);
			else static if (isFloating!T)
				_writeFloating(cast(double)arg, 10, fg, bg, flags);
			else
				_write(arg.toString, fg, bg, flags);
		}

		if (_onChanged)
			_onChanged(startPos, _count);
	}

	void writeln(Args...)(Args args) {
		write(args, '\n');
	}

	void writef(Args...)(wstring format, Args args) {
		size_t startPos = _count;
		static assert(0);

		if (_onChanged)
			_onChanged(startPos, _count);
	}

	void writefln(Args...)(wstring format, Args args) {
		size_t startPos = _count;
		OnChangedCallback cb = _onChanged; //Hack to make it only update once.
		_onChanged = null;

		writef(format, args);
		_write('\n');

		_onChanged = cb;
		if (_onChanged)
			_onChanged(startPos, _count);
	}

	void clear() {
		if (_onChanged)
			_onChanged(-1, -1);
	}

	@property Slot[] buffer() {
		return _buffer;
	}

	@property size_t count() {
		return _count;
	}

	@property ref Color foreground() {
		return _defaultFG;
	}

	@property ref Color background() {
		return _defaultBG;
	}

	@property ref SlotFlags flags() {
		return _defaultFlags;
	}

	@property ref OnChangedCallbackType onChangedCallback() {
		return _onChanged;
	}

private:
	enum increaseSize = 0x1000;

	bool _otherBuffer;
	Slot[] _buffer;
	size_t _count;

	Color _defaultFG;
	Color _defaultBG;
	SlotFlags _defaultFlags;

	OnChangedCallbackType _onChanged;

	void _resize() {
		if (_otherBuffer) {
			Slot[] newBuffer = new Slot[_buffer.length + increaseSize];
			foreach (idx, slot; buffer)
				newBuffer[idx] = slot;
			_buffer = newBuffer;
			_otherBuffer = false;
		} else
			_buffer.length += increaseSize;
	}

	void _write(wchar ch, Color fg, Color bg, SlotFlags flags) {
		if (_buffer.length == _count)
			_resize();
		_buffer[_count++] = Slot(ch, fg, bg, flags);
	}

	void _write(in char[] str, Color fg, Color bg, SlotFlags flags) {
		foreach (char ch; str)
			_write(ch, fg, bg, flags);
	}

	void _write(in wchar[] str, Color fg, Color bg, SlotFlags flags) {
		foreach (wchar ch; str)
			_write(ch, fg, bg, flags);
	}

	void _write(char* str, Color fg, Color bg, SlotFlags flags) {
		while (*str)
			_write(*(str++), fg, bg, flags);
	}

	void _writeNumber(S = long)(S value, uint base, Color fg, Color bg, SlotFlags flags) if (isNumber!S) {
		char[S.sizeof * 8] buf;
		_write(itoa(value, buf, base), fg, bg, flags);
	}

	void _writeFloating(double value, uint base, Color fg, Color bg, SlotFlags flags) {
		char[double.sizeof * 8] buf;
		_write(dtoa(value, buf, base), fg, bg, flags);
	}

	void _writeEnum(T)(T value, Color fg, Color bg, SlotFlags flags) if (is(T == enum)) {
		foreach (i, e; enumMembers!T)
			if (value == e) {
				_write(__traits(allMembers, T)[i], fg, bg, flags);
				return;
			}

		_write("cast(", fg, bg, flags);
		_write(T.stringof, fg, bg, flags);
		_write(")", fg, bg, flags);
		_writeNumber(cast(int)value, 10, fg, bg, flags);
	}
}

TextBuffer getBootTTY() {
	import data.util : inplaceClass;

	__gshared TextBuffer textBuffer;
	__gshared ubyte[__traits(classInstanceSize, TextBuffer)] buf;
	__gshared Slot[0x1000] slotBuffer;

	if (!textBuffer)
		textBuffer = inplaceClass!TextBuffer(buf, slotBuffer);
	return textBuffer;
}
