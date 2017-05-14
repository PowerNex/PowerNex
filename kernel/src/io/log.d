module io.log;

import io.com;
import data.address;
import data.string_;
import data.util;

__gshared Log log;

/*

TODO: FIX THIS!!!

	Combine this with textmode aswell.

*/

enum LogLevel {
	verbose = '&',
	debug_ = '+',
	info = '*',
	warning = '#',
	error = '-',
	fatal = '!'
}

struct Log {
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

	private int _indent;
	private bool _enabled;
	private SymbolMap* _symbols;

	// XXX: Page fault if this is not wrapped like this!
	static ulong seconds() {
		import hw.cmos.cmos : getCMOS, isCMOSInited;

		if (isCMOSInited)
			return getCMOS.timeStamp();
		return 0;
	}

	void init() {
		_indent = 0;
		_enabled = true;
	}

	@property ref bool enabled() return  {
		return _enabled;
	}

	void setSymbolMap(VirtAddress address) {
		SymbolMap* map = cast(SymbolMap*)address.ptr;
		if (map.magic[0 .. 4] != "DSYM")
			return;
		_symbols = map;
	}

	void opCall(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Arg...)(LogLevel level, Arg args) {
		char[ulong.sizeof * 8] buf;
		if (!_enabled)
			return;
		for (int i = 0; i < _indent; i++)
			com1.write(' ');

		com1.write('[', itoa(seconds(), buf, 10), ']');
		com1.write('[', cast(char)level, "] ", file /*, ": ", func*/ , '@');

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
			else static if (is(T : char))
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
	}

	void verbose(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Arg...)(Arg args) {
		this.opCall!(file, func, line)(LogLevel.verbose, args);
	}

	void debug_(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Arg...)(Arg args) {
		this.opCall!(file, func, line)(LogLevel.debug_, args);
	}

	void info(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Arg...)(Arg args) {
		this.opCall!(file, func, line)(LogLevel.info, args);
	}

	void warning(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Arg...)(Arg args) {
		this.opCall!(file, func, line)(LogLevel.warning, args);
	}

	void error(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Arg...)(Arg args) {
		this.opCall!(file, func, line)(LogLevel.error, args);
	}

	void fatal(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Arg...)(Arg args) {
		this.opCall!(file, func, line)(LogLevel.fatal, args);
		printStackTrace(true);
		import io.textmode : getScreen;

		getScreen.writeStatus("\t\tFATAL ERROR, READ COM.LOG!");
		asm {
		forever:
			hlt;
			jmp forever;
		}
	}

	void printStackTrace(bool skipFirst = false) {
		import memory.ref_ : Ref;
		import task.scheduler : getScheduler;
		import task.process : Process;

		VirtAddress rbp;
		asm {
			mov rbp, RBP;
		}
		_printStackTrace(rbp, skipFirst);

		if (Ref!Process p = getScheduler.currentProcess)
			if (!(*p).kernelProcess) {
				auto page = (*p).threadState.paging.getPage((*p).syscallRegisters.rbp);
				if (!page || !page.present)
					return;
				_printStackTrace((*p).syscallRegisters.rbp, skipFirst);
			}
	}

	private void _printStackTrace(VirtAddress rbp, bool skipFirst) {
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

			import task.scheduler : getScheduler, TablePtr;

			if (getScheduler && getScheduler.currentProcess) {
				TablePtr!(void)* page = (*getScheduler.currentProcess).threadState.paging.getPage(rip);
				if (!page || !page.present)
					break;
			}

			com1.write("\t[");

			{
				char[ulong.sizeof * 8] buf;
				com1.write("0x");
				com1.write(itoa(*rip.ptr!ulong, buf, 16));
			}

			com1.write("] ");

			struct Func {
				string name;
				ulong diff;
			}

			Func getFuncName(ulong addr) {
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
				char[ulong.sizeof * 8] buf;
				com1.write("+0x");
				com1.write(itoa(f.diff, buf, 16));
			}

			com1.write("\r\n");
			rbp = VirtAddress(*rbp.ptr!ulong);
		}
	}

}
