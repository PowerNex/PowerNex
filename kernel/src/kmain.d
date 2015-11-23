module kmain;

import io.log;
import io.textmode;
import cpu.gdt;
import cpu.idt;
import multiboot;

alias scr = GetScreen;
alias gdt = GDT;
alias idt = IDT;

immutable uint major = __VERSION__ / 1000;
immutable uint minor = __VERSION__ % 1000;

extern (C) int kmain(uint magic, ulong info) {
	scr.Clear();
	gdt.Init();
	idt.Init();

	scr.Writeln("Welcome to PowerNex!");
	scr.Writeln("\tThe number one D kernel!");
	scr.Write("Compiled using '", __VENDOR__, "', D version ", major, ".", minor, "\n");

	log.Info("Welcome to PowerNex's serial console!");

	Multiboot.ParseHeader(magic, info);

	asm {
	forever:
		hlt;
		jmp forever;
	}
	return 0;
}
