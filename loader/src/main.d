module main;

import api.info : PowerDInfo;
import io.vga : VGA;
import io.log : Log;

static private immutable uint _major = __VERSION__ / 1000;
static private immutable uint _minor = __VERSION__ % 1000;

private extern extern (C) __gshared PowerDInfo powerDInfo;
private ref PowerDInfo getPowerDInfo() @trusted {
	return powerDInfo;
}

private void outputBoth(Args...)(Args args) @safe {
	VGA.writeln(args);
	Log.info(args);
}

///
extern (C) ulong main() @safe {
	() @trusted{ //
		import arch.amd64.gdt : GDT;
		import arch.amd64.idt : IDT;

		GDT.init();

		IDT.init();
	}();

	Log.init();
	VGA.init();

	outputBoth("Hello world from D!");
	outputBoth("\tCompiled using '", __VENDOR__, "', D version ", _major, ".", _minor);

	{
		import api.info : PowerDInfoMagic, Version;

		with (getPowerDInfo) {
			magic = PowerDInfoMagic;
			version_ = Version(0, 0, 0); // TODO: Sync with init32.S somehow
		}
	}

	return 0;
}
