module main;

import api : APIInfo;
import io.vga : VGA;
import io.log : Log;

static private immutable uint _major = __VERSION__ / 1000;
static private immutable uint _minor = __VERSION__ % 1000;

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

	APIInfo.init();

	return 0;
}
