module kmain;

import io.log;
import io.textmode;

alias scr = GetScreen;

immutable uint major = __VERSION__ / 1000;
immutable uint minor = __VERSION__ % 1000;

extern(C) int kmain(uint magic, ulong info) {
	scr.Clear();
	scr.Writeln("Welcome to PowerNex!");
	scr.Writeln("\tThe number one D kernel!");
	scr.Write("Compiled using '", __VENDOR__, "', D version ", major, ".", minor, "\n");

	log.Info("Welcome to PowerNex's serial console!");

	scr.Write("Bootmagic is: ");
	scr.WriteNumber(magic, 16);
	scr.Writeln();

	asm {
		forever:
			hlt;
			jmp forever;
	}
	return 0;
}
