module KMain;

import IO.Log;
import IO.TextMode;
import CPU.GDT;
import CPU.IDT;
import Data.Multiboot;
import Memory.Paging;
import Memory.FrameAllocator;
import Data.Linker;
import Data.Address;
import Memory.Heap;

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

	DirectoryNode root = new InitrdRootNode(initrd[0]);
	scr.Writeln("Root: ", root.toString);

	void printDir(DirectoryNode dir, int indent = 1) {
		foreach (node; dir.NodeList) {
			for (int i = 0; i < indent; i++)
				scr.Write("  ");
			scr.Writeln(node.ID, ": ", node.Name);
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

	printDir(root);
	root.destroy();

	root = new SystemRootNode();
	scr.Writeln("Root: ", root.toString);
	printDir(root);
	root.destroy();

	scr.Writeln();
}
