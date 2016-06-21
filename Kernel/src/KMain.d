module KMain;

version (PowerNex) {
	// Good job, you are now able to compile PowerNex!
} else {
	static assert(0, "Please use the customized toolchain located here: http://wild.tk/PowerNex-Env.tar.xz");
}

import IO.Log;
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
import ACPI.RSDP;
import HW.BGA.BGA;
import HW.BGA.PSF;
import HW.PCI.PCI;
import HW.CMOS.CMOS;
import Data.TextBuffer : scr = GetBootTTY;

import Bin.BasicShell;

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

	import IO.FS.FileNode;
	import Data.BMPImage;
	import HW.BGA.BGA;

	BMPImage bmp = new BMPImage(cast(FileNode)rootFS.Root.FindNode("/Data/DLogo.bmp"));
	GetBGA.RenderBMP(bmp);
	bmp.destroy;

	scheduler.AddThread(new BasicShellThread());
	while (true) {
	}

	scr.Foreground = Color(255, 0, 255);
	scr.Background = Color(255, 255, 0);
	scr.Writeln("kmain functions has exited!");
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

	scr.Writeln("PCI initializing...");
	GetPCI;

	scr.Writeln("Initrd initializing...");
	LoadInitrd();

	scr.Writeln("BGA initializing...");
	GetBGA.Init(new PSF(cast(FileNode)rootFS.Root.FindNode("/Data/Font/TTYFont.psf")));

	scheduler = new Scheduler();
	scr.Writeln("Scheduler initializing...");
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
