module KMain;

import IO.Log;
import IO.TextMode;
import IO.Keyboard;
import IO.FS;
import CPU.GDT;
import CPU.IDT;
import CPU.PIT;
import Data.Multiboot;
import Memory.Paging;
import Memory.FrameAllocator;
import Data.Linker;
import Data.Address;
import Memory.Heap;

alias scr = GetScreen;

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

	scr.Writeln();
	scr.Writeln("User input:");

	char key;
	VirtAddress timePosition = VirtAddress(0xFFFF_FFFF_800B_8000) + (80 * 1 - 1) * 2;
	while (key != 27 /* Escape */ ) {
		// Print out seconds since boot, in the top right corner
		ulong tmp = PIT.Seconds;
		*((timePosition - (0 * 2)).Ptr!ubyte) = '0' + tmp % 10;
		tmp /= 10;
		*((timePosition - (1 * 2)).Ptr!ubyte) = '0' + tmp % 10;
		tmp /= 10;
		*((timePosition - (2 * 2)).Ptr!ubyte) = '0' + tmp % 10;

		// Get User input and write it out
		key = Keyboard.Get();
		if (key)
			scr.Write(key);
	}
	scr.Writeln();

	scr.color.Foreground = Colors.Magenta;
	scr.color.Background = Colors.Yellow;
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
	Keyboard.Init();
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
}

void LoadInitrd() {
	import IO.FS;
	import IO.FS.Initrd;
	import IO.FS.System;

	scr.Writeln();
	scr.color.Foreground = Colors.Green;
	auto initrd = Multiboot.GetModule("initrd");
	if (initrd[0] == initrd[1]) {
		scr.Writeln("Initrd missing");
		log.Error("Initrd missing");
		return;
	}

	void printDir(DirectoryNode dir, int indent = 0) {
		foreach (idx, node; dir.Nodes) {
			for (int i = 0; i < indent; i++)
				scr.Write("  ");
			scr.Writeln(node.ID, "(", idx, "): ", node.Name);
			if (auto f = cast(FileNode)node) {
				scr.color.Foreground = Colors.Yellow;
				scr.color.Background = Colors.Blue;

				ubyte[64] buf = void;
				auto len = f.Read(buf, 0);
				scr.Writeln(cast(string)buf[0 .. len]);

				scr.color.Foreground = Colors.Green;
				scr.color.Background = Colors.Black;
			} else if (auto d = cast(DirectoryNode)node)
				printDir(d, indent + 1);
		}
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
	scr.Writeln("Root: ", rootFS.toString);

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

	printDir(rootFS.Root);
	scr.Writeln();
}
