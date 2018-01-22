module kmain;

import data.util : isVersion;

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
import cpu.gdt;
import cpu.idt;
import cpu.pit;
import data.color;
import data.multiboot;
import hw.ps2.keyboard;
import memory.frameallocator;
import data.linker;
import data.address;
import memory.kheap;
import acpi.rsdp;
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
	preInit(papi);
	welcome();
	//init(magic, info);
	//asm pure nothrow {
	//	sti;
	//}

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
	Log.fatal("kmain functions has exited!");
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

	COM.init();
	// TODO: Make sure that it only append on the loader output, not replaces it.
	scr;
	scr.onChangedCallback = &bootTTYToTextmode;
	getScreen.setCoord(papi.screenX, papi.screenY);
	//getScreen.clear();

	scr.writeln("Log initializing...");
	Log.init();
	Log.info("Log is now enabled!");

	scr.writeln("GDT initializing...");
	Log.info("GDT initializing...");
	GDT.init();

	scr.writeln("IDT initializing...");
	Log.info("IDT initializing...");
	//IDT.init();

	scr.writeln("Syscall Handler initializing...");
	Log.info("Syscall Handler initializing...");
	SyscallHandler.init();

	scr.writeln("PIT initializing...");
	Log.info("PIT initializing...");
	//PIT.init();
}

void welcome() {
	scr.writeln("Welcome to PowerNex!");
	scr.writeln("\tThe number one D kernel!");
	scr.writeln("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");
	Log.info("Welcome to PowerNex's serial console!");
	Log.info("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");
}

/+ void init(uint magic, ulong info) {
	scr.writeln("Multiboot parsing...");
	Log.info("Multiboot parsing...");
	Multiboot.parseHeader(magic, info);

	scr.writeln("FrameAllocator initializing...");
	Log.info("FrameAllocator initializing...");
	FrameAllocator.init();

	scr.writeln("KernelHWPaging initializing...");
	Log.info("KernelHWPaging initializing...");

	initKernelHWPaging();

	scr.writeln("KernelHWPaging WORKED");
	Log.info("KernelHWPaging WORKED");

	scr.writeln("KHeap initializing...");
	Log.info("KHeap initializing...");

	KHeap.init();
	initKernelAllocator();

	scr.writeln("ACPI initializing...");
	Log.info("ACPI initializing...");
	rsdp.init();

	scr.writeln("CMOS initializing...");
	Log.info("CMOS initializing...");
	CMOS.init(rsdp.fadtInstance.century);

	scr.writeln("Keyboard initializing...");
	Log.info("Keyboard initializing...");
	PS2Keyboard.init();

	{
		VirtAddress[2] symmap = Multiboot.getModule("symmap");
		if (symmap[0]) {
			//Log.setSymbolMap(symmap[0]);
			Log.info("Successfully loaded symbols!");
		} else
			Log.fatal("No module called symmap!");
	}

	scr.writeln("PCI initializing...");
	Log.info("PCI initializing...");
	PCI.init();

	scr.writeln("Initrd initializing...");
	Log.info("Initrd initializing...");
	loadInitrd();

	scr.writeln("Starting ConsoleManager...");
	Log.info("Starting ConsoleManager...");
	ConsoleManager.init();

	/*scr.writeln("Scheduler initializing...");
	Log.info("Scheduler initializing...");
	getScheduler.init();*/
} +/

/+ void loadInitrd() {
	import fs.tarfs : TarFS;
	import fs.iofs : IOFS;

	VirtAddress[2] tarfsLoc = Multiboot.getModule("tarfs");
	if (!tarfsLoc[0]) {
		Log.fatal("No module called tarfs!");
		return;
	}

	ubyte[] tarfsData = VirtAddress().ptr!ubyte[tarfsLoc[0].num .. tarfsLoc[1].num];
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
} +/
