module main;

import io.vga : screen;
import io.log : log;

static private immutable uint _major = __VERSION__ / 1000;
static private immutable uint _minor = __VERSION__ % 1000;

private void outputBoth(Args...)(Args args) {
	screen.writeln(args);
	log.info(args);
}

///
extern (C) ulong main() @safe {
	/*() @trusted{ import arch.amd64.gdt : GDT;

	GDT.init(); import arch.amd64.idt : IDT;

	IDT.init(); }();*/

	screen.writeln("Hello world from D!");
	screen.writeln("\tCompiled using '", __VENDOR__, "', D version ", _major, ".", _minor);
	return 0;
}
