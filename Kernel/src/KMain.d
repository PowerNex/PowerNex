module KMain;

version (PowerNex) {
	// Good job, you are now able to compile PowerNex!
} else {
	static assert(0, "Please use the customized toolchain located here: http://wild.tk/PowerNex-Env.tar.xz");
}

import IO.COM;
import IO.Log;
import IO.Keyboard;
import IO.FS;
import CPU.GDT;
import CPU.IDT;
import CPU.PIT;
import Data.Color;
import Data.Multiboot;
import HW.PS2.Keyboard;
import Memory.Paging;
import Memory.FrameAllocator;
import Data.Linker;
import Data.Address;
import Memory.Heap;
import Task.Scheduler;
import ACPI.RSDP;
import HW.BGA.BGA;
import HW.BGA.PSF;
import HW.PCI.PCI;
import HW.CMOS.CMOS;
import System.SyscallHandler;
import Data.TextBuffer : scr = GetBootTTY;
import Data.ELF;
import IO.ConsoleManager;
import IO.FS.IO.Console;

immutable uint major = __VERSION__ / 1000;
immutable uint minor = __VERSION__ % 1000;

__gshared FSRoot rootFS;

extern (C) int kmain(uint magic, ulong info) {
	PreInit();
	Welcome();
	Init(magic, info);
	asm {
		sti;
	}

	string initFile = "/Binary/Init";

	ELF init = new ELF(cast(FileNode)rootFS.Root.FindNode(initFile));
	if (init.Valid) {
		scr.Writeln(initFile, " is valid! Loading...");

		scr.Writeln();
		scr.Foreground = Color(255, 255, 0);
		init.MapAndRun([initFile]);
	} else {
		scr.Writeln("Invalid ELF64 file");
		log.Fatal("Invalid ELF64 file!");
	}

	scr.Foreground = Color(255, 0, 255);
	scr.Background = Color(255, 255, 0);
	scr.Writeln("kmain functions has exited!");
	log.Fatal("kmain functions has exited!");
	return 0;
}

void BootTTYToTextmode(size_t start, size_t end) {
	import IO.TextMode;

	if (start == -1 && end == -1)
		GetScreen.Clear();
	else
		GetScreen.Write(scr.Buffer[start .. end]);
}

void PreInit() {
	import IO.TextMode;

	COM.Init();

	scr;
	scr.OnChangedCallback = &BootTTYToTextmode;
	GetScreen.Clear();

	scr.Writeln("ACPI initializing...");
	rsdp.Init();

	scr.Writeln("CMOS initializing...");
	GetCMOS();

	scr.Writeln("Log initializing...");
	log.Init();

	scr.Writeln("GDT initializing...");
	GDT.Init();

	scr.Writeln("IDT initializing...");
	IDT.Init();

	scr.Writeln("Syscall Handler initializing...");
	SyscallHandler.Init();

	scr.Writeln("PIT initializing...");
	PIT.Init();

	scr.Writeln("Keyboard initializing...");
	PS2Keyboard.Init();
}

void Welcome() {
	scr.Writeln("Welcome to PowerNex!");
	scr.Writeln("\tThe number one D kernel!");
	scr.Writeln("Compiled using '", __VENDOR__, "', D version ", major, ".", minor, "\n");

	log.Info("Welcome to PowerNex's serial console!");
	log.Info("Compiled using '", __VENDOR__, "', D version ", major, ".", minor, "\n");
}

void Init(uint magic, ulong info) {
	scr.Writeln("Multiboot parsing...");
	Multiboot.ParseHeader(magic, info);

	scr.Writeln("FrameAllocator initializing...");
	FrameAllocator.Init();

	scr.Writeln("Paging initializing...");
	GetKernelPaging.RemoveUserspace(false); // Removes all mapping that are not needed for the kernel
	GetKernelPaging.Install();

	scr.Writeln("Heap initializing...");
	GetKernelHeap;

	scr.Writeln("PCI initializing...");
	GetPCI;

	scr.Writeln("Initrd initializing...");
	LoadInitrd();

	scr.Writeln("Starting ConsoleManager...");
	GetConsoleManager.Init();

	scr.Writeln("Scheduler initializing...");
	GetScheduler.Init();
}

void LoadInitrd() {
	import IO.FS;
	import IO.FS.Initrd;
	import IO.FS.System;
	import IO.FS.IO;

	auto initrd = Multiboot.GetModule("initrd");
	if (initrd[0] == initrd[1]) {
		scr.Writeln("Initrd missing");
		log.Error("Initrd missing");
		return;
	}

	void mount(string path, FSRoot fs) {
		Node mp = rootFS.Root.FindNode(path);
		if (mp && !cast(DirectoryNode)mp) {
			log.Error(path, " is not a DirectoryNode!");
			return;
		}
		if (!mp) {
			mp = new DirectoryNode(NodePermissions.DefaultPermissions);
			mp.Name = path[1 .. $];
			mp.Root = rootFS;
			mp.Parent = rootFS.Root;
		}

		DirectoryNode mpDir = cast(DirectoryNode)mp;
		mpDir.Parent.Mount(mpDir, fs);
	}

	rootFS = new InitrdFSRoot(initrd[0]);

	Node file = rootFS.Root.FindNode("/Data/PowerNex.map");
	if (!file) {
		log.Warning("Could not find the symbol file!");
		return;
	}
	InitrdFileNode symbols = cast(InitrdFileNode)file;
	if (!symbols) {
		log.Error("Symbol file is not of the type InitrdFileNode! It's a ", typeid(file).name);
		return;
	}
	log.SetSymbolMap(VirtAddress(symbols.RawAccess.ptr));
	log.Info("Successfully loaded symbols!");

	mount("/IO", new IOFSRoot());
	mount("/System", new SystemFSRoot());
}
