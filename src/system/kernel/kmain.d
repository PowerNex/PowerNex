module kmain;

import stl.arch.amd64.com;
import stl.io.log;
import stl.io.vga;
import stl.arch.amd64.gdt;
import stl.arch.amd64.idt;
import stl.arch.amd64.lapic;
import hw.ps2.keyboard;
import stl.vmm.frameallocator;
import stl.address;
import stl.vmm.heap;
import hw.pci.pci;
import hw.cmos.cmos;
import arch.paging;
import stl.vmm.vmm;

import powerd.api;

private immutable uint _major = __VERSION__ / 1000;
private immutable uint _minor = __VERSION__ % 1000;

extern (C) void kmain(PowerDAPI* papi) {
	assert(papi.magic == PowerDAPI.magicValue);
	preInit(papi);
	welcome();
	init(papi);
	asm pure nothrow {
		sti;
	}

	/*string initFile = "/bin/init";
	ELF init = new ELF((*rootFS).root.findNode(initFile));
	if (init.valid) {
		VGA.writeln(initFile, " is valid! Loading...");
		VGA.writeln();
		VGA.foreground = Color(255, 255, 0);
		init.mapAndRun([initFile]);
	} else {
		VGA.writeln("Invalid ELF64 file");
		Log.fatal("Invalid ELF64 file!");
	}*/

	VGA.color = CGASlotColor(CGAColor.red, CGAColor.yellow);
	VGA.writeln("kmain functions has exited!");
	Log.error("kmain functions has exited!");
	while (true) {
	}
}

void preInit(PowerDAPI* papi) {
	COM.init();
	VGA.x = papi.screenX;
	VGA.y = papi.screenY;

	VGA.writeln("Log initializing...");
	//Log.init();
	Log.info("Log is now enabled!");

	VGA.writeln("LAPIC initializing...");
	Log.info("LAPIC initializing...");
	LAPIC.init();

	VGA.writeln("GDT initializing...");
	Log.info("GDT initializing...");
	GDT.init();

	VGA.writeln("IDT initializing...");
	Log.info("IDT initializing...");
	IDT.init();
}

void welcome() {
	VGA.writeln("Welcome to PowerNex!");
	VGA.writeln("\tThe number one D kernel!");
	VGA.writeln("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");
	Log.info("Welcome to PowerNex's serial console!");
	Log.info("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");
}

void init(PowerDAPI* papi) {
	VGA.writeln("FrameAllocator initializing...");
	Log.info("FrameAllocator initializing...");
	FrameAllocator.init(papi.memory.maxFrames, papi.memory.usedFrames, papi.memory.bitmaps, papi.memory.currentBitmapIdx);

	VGA.writeln("KernelPaging initializing...");
	Log.info("KernelPaging initializing...");

	initKernelPaging();

	VGA.writeln("KernelPaging WORKED");
	Log.info("KernelPaging WORKED");

	VGA.writeln("Heap initializing...");
	Log.info("Heap initializing...");

	Heap.init();

	VGA.writeln("CMOS initializing...");
	Log.info("CMOS initializing...");
	CMOS.init(papi.acpi.century);

	VGA.writeln("Keyboard initializing...");
	Log.info("Keyboard initializing...");
	PS2Keyboard.init();

	{
		// TODO: Get symbolmap from ELF file
		Module* symmap = papi.getModule("kernel");
		if (symmap) {
			//Log.setSymbolMap(symmap);
			Log.info("Successfully loaded symbols!");
		} else
			Log.error("No module called symmap!");
	}

	VGA.writeln("PCI initializing...");
	Log.info("PCI initializing...");
	PCI.init();
}
