module kmain;

import io.log;
import io.textmode;
import cpu.gdt;
import cpu.idt;
import multiboot;
import memory.paging;
import memory.frameallocator;
import linker;
import data.address;
import memory.heap;

alias scr = GetScreen;

immutable uint major = __VERSION__ / 1000;
immutable uint minor = __VERSION__ % 1000;

extern (C) int kmain(uint magic, ulong info) {
	PreInit();
	Welcome();
	Init(magic, info);

	scr.color.Foreground = Colors.Magenta;
	scr.color.Background = Colors.Yellow;
	scr.Writeln("kmain functions has exited!");
	return 0;
}

void PreInit() {
	scr.Clear();
	GDT.Init();
	IDT.Init();
	log.Init();
}

void Welcome() {
	scr.Writeln("Welcome to PowerNex!");
	scr.Writeln("\tThe number one D kernel!");
	scr.Writeln("Compiled using '", __VENDOR__, "', D version ", major, ".", minor, "\n");

	log.Info("Welcome to PowerNex's serial console!");
	log.Info("Compiled using '", __VENDOR__, "', D version ", major, ".", minor, "\n");
}

void Init(uint magic, ulong info) {
	Multiboot.ParseHeader(magic, info);
	FrameAllocator.Init();
	auto symbols = Multiboot.GetModule("symbols");
	if (symbols[0] != symbols[1])
		log.SetSymbolMap(symbols[0], symbols[1]);
	GetKernelPaging.Install();
	GetKernelHeap;
}
