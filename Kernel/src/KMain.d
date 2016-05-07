module KMain;

version (PowerNex) {
	// Good job, you are now able to compile PowerNex!
} else {
	static assert(0, "Please use the customized toolchain located here: http://wild.tk/PowerNex-Env.tar.xz");
}

import IO.Log;
import IO.TextMode;
import IO.Keyboard;
import IO.FS;
import CPU.GDT;
import CPU.IDT;
import CPU.PIT;
import Data.Multiboot;
import HW.PS2.Keyboard;
import Memory.Paging;
import Memory.FrameAllocator;
import Data.Linker;
import Data.Address;
import Memory.Heap;
import Task.Scheduler;
import Task.Thread;

alias scr = GetScreen;

immutable uint major = __VERSION__ / 1000;
immutable uint minor = __VERSION__ % 1000;

__gshared FSRoot rootFS;

void shell() {
	dchar key;
	import HW.PS2.KBSet : KeyCode;

	scr.Writeln();
	scr.Writeln("User input:");

	while (true) {
		// Get User input and write it out
		key = Keyboard.Pop();
		if (key != '\0' && key < 0x100 && key != 27)
			scr.Write(cast(char)key);
	}
}

void b() {
	int counter;
	while (true) {
		counter++;
		const VirtAddress pos = VirtAddress(0xFFFF_FFFF_800B_8000) + (80 * 2 - 1) * 2;
		*((pos - (0 * 2)).Ptr!ubyte) = cast(ubyte)(counter % 255);
		*((pos - (1 * 2)).Ptr!ubyte) = cast(ubyte)((counter * 3) % 255);
		*((pos - (2 * 2)).Ptr!ubyte) = cast(ubyte)((counter * 5) % 255);
		scheduler.Schedule();
	}
}

extern (C) int kmain(uint magic, ulong info) {
	PreInit();
	Welcome();
	Init(magic, info);
	asm {
		sti;
	}

	KernelThread shellProc = new KernelThread(&shell);
	scheduler.AddThread(shellProc);

	KernelThread bProc = new KernelThread(&b);
	scheduler.AddThread(bProc);

	while (true) {
		scheduler.Schedule();
	}

	scr.CurrentColor.Foreground = Colors.Magenta;
	scr.CurrentColor.Background = Colors.Yellow;
	scr.Writeln("kmain functions has exited!");
	return 0;
}

void PreInit() {
	scr.Clear();
	scr.Writeln("Log initializing...");
	log.Init();
	scr.Writeln("GDT initializing...");
	GDT.Init();
	scr.Writeln("IDT initializing...");
	IDT.Init();
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
	GetKernelPaging.Install();

	scr.Writeln("Heap initializing...");
	GetKernelHeap;

	scr.Writeln("Initrd initializing...");
	LoadInitrd();

	scheduler = new Scheduler();
}

void LoadInitrd() {
	import IO.FS;
	import IO.FS.Initrd;
	import IO.FS.System;

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

	mount("/System", new SystemFSRoot());
}
