module io.log;

///
enum LogLevel {
	verbose = 0,
	debug_,
	info,
	warning,
	error,
	fatal
}

///
char toChar(LogLevel level) @trusted {
	// dfmt off
	__gshared static char[LogLevel.max + 1] data = [
		LogLevel.verbose: '&',
		LogLevel.debug_: '+',
		LogLevel.info: '*',
		LogLevel.warning: '#',
		LogLevel.error: '-',
		LogLevel.fatal: '!'
	];
	// dfmt on

	return data[level];
}

///
@trusted static struct Log {
public static:

	/// XXX: Page fault if this is not wrapped like this!
	static ulong seconds() {
		return 0;
		/*import hw.cmos.cmos : CMOS;

		return CMOS.timeStamp();*/
	}

	///
	void init() {
		_indent = 0;
	}

///
	void setSymbolMap(from!"data.address".VirtAddress address) @trusted {
		import data.address : VirtAddress;

		SymbolMap* map = cast(SymbolMap*)address.ptr;
		if (map.magic[0 .. 4] != "DSYM")
			return;
		_symbols = map;
	}

///
	void opCall(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Args...)(LogLevel level, Args args) {
		log(level, file, func, line, args);
	}

///
	void log(Args...)(LogLevel level, string file, string func, int line, Args args) {
		import io.com : com1;
		import data.text : itoa, BinaryInt;
		import util.trait : Unqual, enumMembers, isNumber, isFloating;
		import data.address : VirtAddress, PhysAddress, PhysAddress32;

		char[ulong.sizeof * 8] buf;
		for (int i = 0; i < _indent; i++)
			com1.write(' ');

		com1.write('[', itoa(seconds(), buf, 10), ']');
		com1.write('[', level.toChar, "] ", file /*, ": ", func*/ , '@');

		com1.write(itoa(line, buf, 10));
		com1.write("> ");
		mainloop: foreach (arg; args) {
			alias T = Unqual!(typeof(arg));
			static if (is(T : const char[]))
				com1.write(arg);
			else static if (is(T == enum)) {
				foreach (i, e; enumMembers!T)
					if (arg == e) {
						com1.write(__traits(allMembers, T)[i]);
						continue mainloop;
					}
				com1.write("cast(");
				com1.write(T.stringof);
				com1.write(")");
				com1.write(itoa(cast(ulong)arg, buf, 10));
			} else static if (is(T == BinaryInt)) {
				com1.write("0b");
				com1.write(itoa(arg.num, buf, 2));
			} else static if (is(T : V*, V)) {
				com1.write("0x");
				com1.write(itoa(cast(ulong)arg, buf, 16));
			} else static if (is(T == VirtAddress) || is(T == PhysAddress) || is(T == PhysAddress32)) {
				com1.write("0x");
				com1.write(itoa(cast(ulong)arg.num, buf, 16));
			} else static if (is(T == bool))
				com1.write((arg) ? "true" : "false");
			else static if (is(T == char))
				com1.write(arg);
			else static if (isNumber!T)
				com1.write(itoa(arg, buf, 10));
			else static if (is(T : ubyte[])) {
				com1.write("[");
				foreach (idx, a; arg) {
					if (idx)
						com1.write(", ");
					com1.write(itoa(a, buf, 16));
				}
				com1.write("]");
			} else static if (isFloating!T)
				com1.write(dtoa(cast(double)arg, buf, 10));
			else
				com1.write("UNKNOWN TYPE '", T.stringof, "'");
		}

		com1.write("\r\n");

		if (level == LogLevel.fatal) {
			printStackTrace(true);

			asm pure nothrow @trusted {
			forever:
				hlt;
				jmp forever;
			}
		}
	}

	///
	mixin(_helperFunctions());

	///
	void printStackTrace(bool skipFirst = false) @trusted {
		import data.address : VirtAddress;

		VirtAddress rbp;
		asm pure nothrow {
			mov rbp, RBP;
		}
		_printStackTrace(rbp, skipFirst);
	}

private static:

	private struct SymbolDef {
	align(1):
		ulong start;
		ulong end;
		ulong nameLength;
	}

	private struct SymbolMap {
	align(1):
		char[4] magic;
		ulong count;
		SymbolDef symbols;
	}

	__gshared int _indent;
	__gshared SymbolMap* _symbols;

	static string _helperFunctions() {
		if (!__ctfe)
			return "";
		import util.trait : enumMembers;

		string str;
		foreach (level; enumMembers!LogLevel)
			str ~= "///\n\tvoid " ~ __traits(allMembers, LogLevel)[level]
				~ "(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Args...)(Args args) { log(LogLevel." ~ __traits(allMembers,
						LogLevel)[level] ~ ", file, func, line, args); }\n\n\t";

		return str;
	}

	void _printStackTrace(from!"data.address".VirtAddress rbp, bool skipFirst) {
		import data.address : VirtAddress;
		import io.com : com1;

		com1.write("\r\nSTACKTRACE:\r\n");
		VirtAddress rip;

		if (skipFirst) {
			rip = rbp + ulong.sizeof;
			rbp = VirtAddress(*rbp.ptr!ulong);
		}

		while (rbp && //
				rbp > 0xFFFF_FFFF_8000_0000 && rbp < 0xFFFF_FFFF_F000_0000 // XXX: Hax fix
				) {
			rip = rbp + ulong.sizeof;
			if (!*rip.ptr!ulong)
				break;

			com1.write("\t[");

			{
				import data.text : itoa;

				char[ulong.sizeof * 8] buf;
				com1.write("0x");
				com1.write(itoa(*rip.ptr!ulong, buf, 16));
			}

			com1.write("] ");

			struct Func {
				string name;
				ulong diff;
			}

			Func getFuncName(ulong addr) @trusted {
				if (!_symbols)
					return Func("Unknown function", 0);

				SymbolDef* symbolDef = &_symbols.symbols;
				for (int i = 0; i < _symbols.count; i++) {
					if (symbolDef.start <= addr && addr <= symbolDef.end)
						return Func(cast(string)(VirtAddress(symbolDef) + SymbolDef.sizeof).ptr[0 .. symbolDef.nameLength], addr - symbolDef.start);
					symbolDef = cast(SymbolDef*)(VirtAddress(symbolDef) + SymbolDef.sizeof + symbolDef.nameLength).ptr;
				}

				return Func("Symbol not in map!", 0);
			}

			Func f = getFuncName(*rip.ptr!ulong);

			com1.write(f.name);
			if (f.diff) {
				import data.text : itoa;

				char[ulong.sizeof * 8] buf;
				com1.write("+0x");
				com1.write(itoa(f.diff, buf, 16));
			}

			com1.write("\r\n");
			rbp = VirtAddress(*rbp.ptr!ulong);
		}
	}
}
