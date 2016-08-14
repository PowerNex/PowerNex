module Data.TextBuffer;

import Data.Color;
import Data.String;
import Data.Util;

enum SlotFlags : ushort {
	Nothing,
	Blinking = 1 << 0,
	//Underline = 1 << 1,
	//Bold = 1 << 2,
	Shadow = 1 << 3,
	InvertedColors = 1 << 4,
	FlipX = 1 << 5,
	FlipY = 1 << 6,

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
		this.buffer = buffer;
		otherBuffer = true;

		defaultFG = Color(0, 255, 255);
		defaultBG = Color(0, 0x22, 0x22);
	}

	this(size_t size) {
		buffer = new Slot[size];
		otherBuffer = false;

		defaultFG = Color(0, 255, 255);
		defaultBG = Color(0, 0x22, 0x22);
	}

	~this() {
		if (!otherBuffer)
			buffer.destroy;
	}

	void Write(Args...)(Args args) {
		import Data.Address;
		size_t startPos = count;
		Color fg = defaultFG;
		Color bg = defaultBG;
		SlotFlags flags = defaultFlags;
		foreach (arg; args) {
			alias T = Unqual!(typeof(arg));
			static if (is(T : const char[]))
				write(arg, fg, bg, flags);
			else static if (is(T == BinaryInt)) {
				write("0b", fg, bg, flags);
				writeNumber(cast(ulong)arg, 2, fg, bg, flags);
			} else static if (is(T : V*, V)) {
				write("0x", fg, bg, flags);
				writeNumber(cast(ulong)arg, 16, fg, bg, flags);
			} else static if (is(T == VirtAddress) || is(T == PhysAddress) || is(T == PhysAddress32)) {
				write("0x", fg, bg, flags);
				writeNumber(cast(ulong)arg.Int, 16, fg, bg, flags);
			} else static if (is(T == enum))
				writeEnum(arg, fg, bg, flags);
			else static if (is(T == bool))
				write((arg) ? "true" : "false", fg, bg, flags);
			else static if (is(T : char))
				write(arg, fg, bg, flags);
			else static if (isNumber!T)
				writeNumber(arg, 10, fg, bg, flags);
			else static if (isFloating!T)
				writeFloating(cast(double)arg, 10, fg, bg, flags);
			else
				write(arg.toString, fg, bg, flags);
		}

		if (onChanged)
			onChanged(startPos, count);
	}

	void Writeln(Args...)(Args args) {
		Write(args, '\n');
	}

	void Writef(Args...)(wstring format, Args args) {
		size_t startPos = count;
		static assert(0);

		if (onChanged)
			onChanged(startPos, count);
	}

	void Writefln(Args...)(wstring format, Args args) {
		size_t startPos = count;
		OnChangedCallback cb = onChanged; //Hack to make it only update once.
		onChanged = null;

		Writef(args);
		write('\n');

		onChanged = cb;
		if (onChanged)
			onChanged(startPos, count);
	}

	void Clear() {
		if (onChanged)
			onChanged(-1, -1);
	}

	@property Slot[] Buffer() {
		return buffer;
	}

	@property size_t Count() {
		return count;
	}

	@property ref Color Foreground() {
		return defaultFG;
	}

	@property ref Color Background() {
		return defaultBG;
	}

	@property ref SlotFlags Flags() {
		return defaultFlags;
	}

	@property ref OnChangedCallbackType OnChangedCallback() {
		return onChanged;
	}

private:
	enum IncreaseSize = 0x1000;

	bool otherBuffer;
	Slot[] buffer;
	size_t count;

	Color defaultFG;
	Color defaultBG;
	SlotFlags defaultFlags;

	OnChangedCallbackType onChanged;

	void resize() {
		if (otherBuffer) {
			Slot[] newBuffer = new Slot[buffer.length + IncreaseSize];
			foreach (idx, slot; buffer)
				newBuffer[idx] = slot;
			buffer = newBuffer;
			otherBuffer = false;
		} else
			buffer.length += IncreaseSize;
	}

	void write(wchar ch, Color fg, Color bg, SlotFlags flags) {
		if (buffer.length == count)
			resize();
		buffer[count++] = Slot(ch, fg, bg, flags);
	}

	void write(in char[] str, Color fg, Color bg, SlotFlags flags) {
		foreach (char ch; str)
			write(ch, fg, bg, flags);
	}

	void write(in wchar[] str, Color fg, Color bg, SlotFlags flags) {
		foreach (wchar ch; str)
			write(ch, fg, bg, flags);
	}

	void write(char* str, Color fg, Color bg, SlotFlags flags) {
		while (*str)
			write(*(str++), fg, bg, flags);
	}

	void writeNumber(S = long)(S value, uint base, Color fg, Color bg, SlotFlags flags) if (isNumber!S) {
		char[S.sizeof * 8] buf;
		write(itoa(value, buf, base), fg, bg, flags);
	}

	void writeFloating(double value, uint base, Color fg, Color bg, SlotFlags flags) {
		char[double.sizeof * 8] buf;
		write(dtoa(value, buf, base), fg, bg, flags);
	}

	void writeEnum(T)(T value, Color fg, Color bg, SlotFlags flags) if (is(T == enum)) {
		foreach (i, e; EnumMembers!T)
			if (value == e) {
				write(__traits(allMembers, T)[i], fg, bg, flags);
				return;
			}

		write("cast(", fg, bg, flags);
		write(T.stringof, fg, bg, flags);
		write(")", fg, bg, flags);
		writeNumber(cast(int)value, 10, fg, bg, flags);
	}
}

TextBuffer GetBootTTY() {
	import Data.Util : InplaceClass;

	__gshared TextBuffer textBuffer;
	__gshared ubyte[__traits(classInstanceSize, TextBuffer)] buf;
	__gshared Slot[0x1000] slotBuffer;

	if (!textBuffer)
		textBuffer = InplaceClass!TextBuffer(buf, slotBuffer);
	return textBuffer;
}
