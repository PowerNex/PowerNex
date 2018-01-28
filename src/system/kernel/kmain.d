module kmain;

import stl.trait : isVersion;

static assert(isVersion!"PowerNex", "\x1B[31;1m\n\n
+--------------------------------------- ERROR ---------------------------------------+
|                                                                                     |
|  You need to follow the build steps that are specified inside the README.org file!  |
|                                                                                     |
+-------------------------------------------------------------------------------------+
\n\n\x1B[0m");

import memory.allocator;
import io.com;
import io.log;
import arch.amd64.gdt;
import arch.amd64.idt;
import arch.amd64.pit;
import data.color;
import hw.ps2.keyboard;
import memory.frameallocator;
import data.linker;
import stl.address;
import memory.kheap;
import hw.pci.pci;
import hw.cmos.cmos;
import system.syscallhandler;
import data.textbuffer : scr = getBootTTY;
import data.elf;
import io.consolemanager;
import memory.ptr;
import fs;
import arch.paging;
import memory.vmm;

import powerd.api;

private immutable uint _major = __VERSION__ / 1000;
private immutable uint _minor = __VERSION__ % 1000;

__gshared SharedPtr!FileSystem rootFS;

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
		scr.writeln(initFile, " is valid! Loading...");
		scr.writeln();
		scr.foreground = Color(255, 255, 0);
		init.mapAndRun([initFile]);
	} else {
		scr.writeln("Invalid ELF64 file");
		Log.fatal("Invalid ELF64 file!");
	}*/

	scr.foreground = Color(255, 0, 255);
	scr.background = Color(255, 255, 0);
	scr.writeln("kmain functions has exited!");
	Log.error("kmain functions has exited!");
	while (true) {
	}
}

void bootTTYToTextmode(size_t start, size_t end) {
	import io.textmode;

	if (start == -1 && end == -1)
		getScreen.clear();
	else
		getScreen.write(scr.buffer[start .. end]);
}

void preInit(PowerDAPI* papi) {
	import io.textmode;
	import arch.amd64.lapic : LAPIC;

	COM.init();
	// TODO: Make sure that it only append on the loader output, not replaces it.
	scr;
	scr.onChangedCallback = &bootTTYToTextmode;
	getScreen.setCoord(papi.screenX, papi.screenY);
	//getScreen.clear();

	scr.writeln("Log initializing...");
	Log.init();
	Log.info("Log is now enabled!");

	scr.writeln("LAPIC initializing...");
	Log.info("LAPIC initializing...");
	LAPIC.init();

	scr.writeln("GDT initializing...");
	Log.info("GDT initializing...");
	GDT.init();

	scr.writeln("IDT initializing...");
	Log.info("IDT initializing...");
	IDT.init();

	scr.writeln("Syscall Handler initializing...");
	Log.info("Syscall Handler initializing...");
	SyscallHandler.init();
}

void welcome() {
	scr.writeln("Welcome to PowerNex!");
	scr.writeln("\tThe number one D kernel!");
	scr.writeln("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");
	Log.info("Welcome to PowerNex's serial console!");
	Log.info("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");
}

void init(PowerDAPI* papi) {
	scr.writeln("FrameAllocator initializing...");
	Log.info("FrameAllocator initializing...");
	FrameAllocator.init(papi.memory);

	scr.writeln("KernelHWPaging initializing...");
	Log.info("KernelHWPaging initializing...");

	initKernelHWPaging();

	scr.writeln("KernelHWPaging WORKED");
	Log.info("KernelHWPaging WORKED");

	scr.writeln("KHeap initializing...");
	Log.info("KHeap initializing...");

	KHeap.init();
	initKernelAllocator();

	scr.writeln("CMOS initializing...");
	Log.info("CMOS initializing...");
	CMOS.init(papi.acpi.century);

	scr.writeln("Keyboard initializing...");
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

	scr.writeln("PCI initializing...");
	Log.info("PCI initializing...");
	PCI.init();

	scr.writeln("Initrd initializing...");
	Log.info("Initrd initializing...");
	loadInitrd(papi);

	scr.writeln("Starting ConsoleManager...");
	Log.info("Starting ConsoleManager...");
	ConsoleManager.init();

	/*scr.writeln("Scheduler initializing...");
	Log.info("Scheduler initializing...");
	getScheduler.init();*/
}

void loadInitrd(PowerDAPI* papi) {
	import fs.tarfs : TarFS;
	import fs.iofs : IOFS;

	Module* tarfsLoc = papi.getModule("tarfs");
	if (!tarfsLoc) {
		Log.error("No module called tarfs!");
		return;
	}

	ubyte[] tarfsData = tarfsLoc.memory.toVirtual.array!ubyte; // TODO:
	rootFS = cast(SharedPtr!FileSystem)kernelAllocator.makeSharedPtr!TarFS(tarfsData);

	SharedPtr!FileSystem iofs = cast(SharedPtr!FileSystem)kernelAllocator.makeSharedPtr!IOFS();
	(*(*rootFS).root).mount("io", iofs);

	char[8] levelStr = "||||||||";
	void printData(SharedPtr!VNode node, int level = 0) {
		if ((*node).type == NodeType.directory) {
			SharedPtr!DirectoryEntryRange range;

			IOStatus ret = (*node).dirEntries(range);
			if (ret) {
				Log.error("dirEntries: ", -ret, ", ", (*node).name, "(", (*node).id, ")", " node:", typeid((*node)).name,
						" fs:", typeid((*node).fs).name);
				return;
			}
			int nextLevel = level + 1;
			if (nextLevel > levelStr.length)
				nextLevel = levelStr.length;
			foreach (idx, ref DirectoryEntry e; range.get) {
				if ((e.name.length && e.name[0] == '.') || false)
					continue;
				SharedPtr!VNode n = e.fileSystem.getNode(e.id);
				if (!n)
					continue;
				Log.info(levelStr[0 .. level], "»", e.name, " type: ", (*n).type, " id: ", (*n).id);
				if ((*n).id != (*node).id)
					printData(n, nextLevel);
			}
		}
	}

	Log.info("directoryEntries for rootFS!\n---------------------");
	printData((*rootFS).root);
}
