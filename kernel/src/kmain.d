module kmain;

version (PowerNex) {
	// Good job, you are now able to compile PowerNex!
} else {
	static assert(0, "Please use the customized toolchain located here: http://wild.tk/PowerNex-Env.tar.xz");
}

import io.com;
import io.log;
import io.fs;
import cpu.gdt;
import cpu.idt;
import cpu.pit;
import data.color;
import data.multiboot;
import hw.ps2.keyboard;
import memory.paging;
import memory.frameallocator;
import data.linker;
import data.address;
import memory.heap;
import task.scheduler;
import acpi.rsdp;
import hw.pci.pci;
import hw.cmos.cmos;
import system.syscallhandler;
import data.textbuffer : scr = getBootTTY;
import data.elf;
import io.consolemanager;
import io.fs.io.console;

private immutable uint _major = __VERSION__ / 1000;
private immutable uint _minor = __VERSION__ % 1000;

__gshared FSRoot rootFS;

extern (C) int kmain(uint magic, ulong info) {
	preInit();
	welcome();
	init(magic, info);
	asm {
		sti;
	}

	string initFile = "/bin/init";

	ELF init = new ELF(cast(FileNode)rootFS.root.findNode(initFile));
	if (init.valid) {
		scr.writeln(initFile, " is valid! Loading...");

		scr.writeln();
		scr.foreground = Color(255, 255, 0);
		init.mapAndRun([initFile]);
	} else {
		scr.writeln("Invalid ELF64 file");
		log.fatal("Invalid ELF64 file!");
	}

	scr.foreground = Color(255, 0, 255);
	scr.background = Color(255, 255, 0);
	scr.writeln("kmain functions has exited!");
	log.fatal("kmain functions has exited!");
	return 0;
}

void bootTTYToTextmode(size_t start, size_t end) {
	import io.textmode;

	if (start == -1 && end == -1)
		getScreen.clear();
	else
		getScreen.write(scr.buffer[start .. end]);
}

void preInit() {
	import io.textmode;

	COM.init();
	scr;
	scr.onChangedCallback = &bootTTYToTextmode;
	getScreen.clear();

	scr.writeln("ACPI initializing...");
	rsdp.init();

	scr.writeln("CMOS initializing...");
	getCMOS();

	scr.writeln("Log initializing...");
	log.init();

	scr.writeln("GDT initializing...");
	GDT.init();

	scr.writeln("IDT initializing...");
	IDT.init();

	scr.writeln("Syscall Handler initializing...");
	SyscallHandler.init();

	scr.writeln("PIT initializing...");
	PIT.init();

	scr.writeln("Keyboard initializing...");
	PS2Keyboard.init();
}

void welcome() {
	scr.writeln("Welcome to PowerNex!");
	scr.writeln("\tThe number one D kernel!");
	scr.writeln("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");

	log.info("Welcome to PowerNex's serial console!");
	log.info("Compiled using '", __VENDOR__, "', D version ", _major, ".", _minor, "\n");
}

void init(uint magic, ulong info) {
	scr.writeln("Multiboot parsing...");
	log.info("Multiboot parsing...");
	Multiboot.parseHeader(magic, info);

	scr.writeln("FrameAllocator initializing...");
	log.info("FrameAllocator initializing...");
	FrameAllocator.init();

	scr.writeln("Paging initializing...");
	log.info("Paging initializing...");
	getKernelPaging.removeUserspace(false); // Removes all mapping that are not needed for the kernel
	getKernelPaging.install();

	scr.writeln("Heap initializing...");
	log.info("Heap initializing...");
	getKernelHeap;

	scr.writeln("PCI initializing...");
	log.info("PCI initializing...");
	getPCI;

	scr.writeln("Initrd initializing...");
	log.info("Initrd initializing...");
	loadInitrd();

	scr.writeln("Starting ConsoleManager...");
	log.info("Starting ConsoleManager...");
	getConsoleManager.init();

	scr.writeln("Scheduler initializing...");
	log.info("Scheduler initializing...");
	getScheduler.init();
}

void loadInitrd() {
	import io.fs;
	import io.fs.initrd;
	import io.fs.system;
	import io.fs.io;

	auto initrd = Multiboot.getModule("initrd");
	if (initrd[0] == initrd[1]) {
		scr.writeln("Initrd missing");
		log.error("Initrd missing");
		return;
	}

	void mount(string path, FSRoot fs) {
		Node mp = rootFS.root.findNode(path);
		if (mp && !cast(DirectoryNode)mp) {
			log.error(path, " is not a DirectoryNode!");
			return;
		}
		if (!mp) {
			mp = new DirectoryNode(NodePermissions.defaultPermissions);
			mp.name = path[1 .. $]; //XXX:
			mp.root = rootFS;
			mp.parent = rootFS.root;
		}

		DirectoryNode mpDir = cast(DirectoryNode)mp;
		mpDir.parent.mount(mpDir, fs);
	}

	rootFS = new InitrdFSRoot(initrd[0]);

	Node file = rootFS.root.findNode("/data/powernex.map");
	if (!file) {
		log.warning("Could not find the symbol file!");
		return;
	}
	InitrdFileNode symbols = cast(InitrdFileNode)file;
	if (!symbols) {
		log.error("Symbol file is not of the type InitrdFileNode! It's a ", typeid(file).name);
		return;
	}
	log.setSymbolMap(VirtAddress(symbols.rawAccess.ptr));
	log.info("Successfully loaded symbols!");

	log.info("Mounting /io!");
	mount("/io", new IOFSRoot());
	log.info("Mounting /system!");
	mount("/system", new SystemFSRoot());
}
