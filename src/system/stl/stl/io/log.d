/**
 * Contains everything related to logging.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.io.log;

import stl.address;

///
@safe enum LogLevel {
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
	import stl.elf64 : ELF64Symbol;

public static:

	/// XXX: Page fault if this is not wrapped like this!
	static ulong seconds() {
		return 0;
		/*import hw.cmos.cmos : CMOS;

		return CMOS.timeStamp();*/
	}

	///
	void setSymbolMap(ELF64Symbol[] symbols, char[] strings) @trusted {
		_symbols = symbols;
		_strings = strings;
	}

	///
	void log(Args...)(LogLevel level, Args args, string file, string func, int line) {
		import stl.arch.amd64.com : com1;
		import stl.text : itoa, BinaryInt, HexInt;
		import stl.trait : Unqual, enumMembers, isNumber, isFloating;
		import stl.address : VirtAddress, PhysAddress, PhysAddress32;

		char[ulong.sizeof * 8] buf;

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
				com1.write(itoa(arg.number, buf, 2));
			} else static if (is(T == HexInt)) {
				com1.write("0x");
				com1.write(itoa(arg.number, buf, 16));
			} else static if (is(T : V*, V)) {
				com1.write("0x");
				string val = itoa(cast(ulong)arg, buf, 16, 16);
				foreach (idx; 0 .. 4) {
					if (idx)
						com1.write('_');
					com1.write(val[idx * 4 .. (idx + 1) * 4]);
				}
			} else static if (is(T == VirtAddress) || is(T == PhysAddress) || is(T == PhysAddress32)) {
				com1.write("0x");
				string val = itoa(cast(ulong)arg.num, buf, 16, 16);
				com1.write(val[0 .. 8], '_', val[8 .. 16]);
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
			printStackTrace(2);

			asm pure nothrow @trusted {
			forever:
				cli;
				hlt;
				jmp forever;
			}
		}
	}

	///
	enum _helperFunctionsResult = _helperFunctions!();
	mixin(_helperFunctionsResult);

	///
	void printStackTrace(size_t skipLevels = 0) @trusted {
		import stl.address : VirtAddress;

		VirtAddress rbp;
		asm pure nothrow {
			mov rbp, RBP;
		}

		_printStackTrace(rbp, skipLevels);
	}

	///
	struct Func {
		string name; ///
		ulong diff; ///
	}

	///
	Func getFuncName(VirtAddress addr) @trusted {
		import stl.text : strlen;

		if (!_symbols)
			return Func("No symbol map loaded", 0);

		foreach (symbol; _symbols) {
			if ((symbol.info & 0xF) != 0x2 /* Function */ )
				continue;

			if (addr < symbol.value || addr > symbol.value + symbol.size)
				continue;

			char* name = &_strings[symbol.name];

			return Func(cast(string)name[0 .. name.strlen], (addr - symbol.value).num);
		}

		return Func("Symbol not in map!", 0);
	}

private static:
	__gshared ELF64Symbol[] _symbols;
	__gshared char[] _strings;

	static template _helperFunctions() {
		import stl.trait : enumMembers;

		template data(LogLevel entry) {
			enum data = "///\n\tvoid " ~ __traits(allMembers, LogLevel)[entry]
					~ "(Args...)(Args args, string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__) { log!Args(LogLevel." ~ __traits(allMembers,
							LogLevel)[entry] ~ ", args, file, func, line); }\n\n\t";
		}

		template generateWrapper(ulong idx, Trest...) {
			static if (idx == Trest.length)
				enum generateWrapper = "";
			else
				enum generateWrapper = generateWrapper!(idx + 1, Trest) ~ data!(Trest[idx]);
		}

		enum _helperFunctions = generateWrapper!(enumMembers!LogLevel);
	}

	void _printStackTrace(VirtAddress rbp, size_t skipLevels = 0) {
		import stl.address : VirtAddress;
		import stl.arch.amd64.com : com1;

		com1.write("\r\nSTACKTRACE:\r\n");
		VirtAddress rip;

		while (skipLevels--) {
			rip = rbp + ulong.sizeof;
			rbp = VirtAddress(*rbp.ptr!ulong);
		}

		while (rbp) {
			rip = rbp + ulong.sizeof;
			if (!*rip.ptr!ulong)
				break;

			com1.write("\t[");

			{
				import stl.text : itoa;

				char[ulong.sizeof * 8] buf;
				com1.write("0x");
				com1.write(itoa(*rip.ptr!ulong, buf, 16));
			}

			com1.write("] ");

			Func f = getFuncName(*rip.ptr!VirtAddress);

			com1.write(f.name);
			if (f.diff) {
				import stl.text : itoa;

				char[ulong.sizeof * 8] buf;
				com1.write("+0x");
				com1.write(itoa(f.diff, buf, 16));
			}

			com1.write("\r\n");
			rbp = VirtAddress(*rbp.ptr!ulong);
		}
	}
}
