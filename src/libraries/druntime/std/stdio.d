module std.stdio;

import core.sys.powernex.io;

import std.traits;
import std.text;

@safe:

struct File {
public:
	FileID fileID;

	void writeln(Args...)(Args args) {
		write(args, '\n');
	}

	void write(Args...)(Args args) {
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
		_flush();
	}

private:
	char[256] _buffer;
	size_t _current;

	void _write(char ch) {
		if (_current >= _buffer.length)
			_flush();
		_buffer[_current++] = ch;
	}

	void _write(scope const(char[]) str) {
		if (_current + str.length >= _buffer.length)
			_flush();

		_buffer[_current .. _current + str.length] = str[];
		_current += str.length;
	}

	void _writeNumber(S = long)(S value, uint base) if (isNumber!S) {
		import std.text : itoa;

		char[S.sizeof * 8] buf;
		_write(itoa(value, buf, base));
	}

	void _writePointer(ulong value) {
		import std.text : itoa;

		char[ulong.sizeof * 8] buf;
		_write("0x");
		string val = itoa(value, buf, 16, 16);
		_write(val[0 .. 8]);
		_write('_');
		_write(val[8 .. 16]);
	}

	void _writeFloating(double value, uint base) {
		import std.text : dtoa;

		char[double.sizeof * 8] buf;
		_write(dtoa(value, buf, base));
	}

	void _writeEnum(T)(T value) if (is(T == enum)) {
		import std.traits : enumMembers;

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

	void _flush() {
		if (_current) {
			import core.sys.powernex.io : write;

			write(fileID, _buffer[0 .. _current]);
			_current = 0;
		}
	}
}

@property ref File stdout() @trusted {
	__gshared File f = File(FileID.stdout);
	return f;
}

@property ref File stderr() @trusted {
	__gshared File f = File(FileID.stderr);
	return f;
}

void write(Args...)(Args args) {
	stdout.write(args);
}

void writeln(Args...)(Args args) {
	stdout.write(args, '\n');
}
