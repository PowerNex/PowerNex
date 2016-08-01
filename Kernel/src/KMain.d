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

import Bin.BasicShell;

immutable uint major = __VERSION__ / 1000;
immutable uint minor = __VERSION__ % 1000;

__gshared FSRoot rootFS;

private extern (C) {
	extern __gshared ubyte KERNEL_STACK_START;
	ulong GetCS();
}

import Task.Process : switchToUserMode;

ulong userspace() {
	import System.SyscallCaller : SyscallCaller;

	//
	/*if (!pid)
		pid = SyscallCaller.Fork();*/
	/*asm {
		mov RAX, 2;
		int 0x80;
		mov pid, RAX;
	}*/

	/*__gshared string[] nums = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];
	__gshared string str = "pid is: ";*/
	/*if (!pid)
		testFunc(null);*/

	ulong pid = SyscallCaller.Fork();

	import HW.BGA.BGA : GetBGA;
	import Data.Color;

	auto w = GetBGA.Width;
	Color color = Color(0x88, 0x53, 0x12);
	long x = w - (pid == 0 ? 100 : 50);
	while (true) {
		color.r += 10;
		color.g += 10;
		color.b += 10;
		GetBGA.putRect(x, 50, 25, 25, color);

	}

	return 0xC0DE_0000 + pid;
}

ulong testFunc(void*) {
	import System.SyscallCaller : SyscallCaller;

	string[] nums = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];
	string s1 = "Thread: ";
	string s2 = nums[GetScheduler.CurrentProcess.pid];

	SyscallCaller.Log(&s1, &s2);

	s1 = "\tisKernel: ";
	s2 = (GetCS != 0x1B ? "true" : "false");
	SyscallCaller.Log(&s1, &s2);

	return 0x123_DEAD;
}

extern (C) int kmain(uint magic, ulong info) {
	PreInit();
	Welcome();
	Init(magic, info);
	asm {
		sti;
	}

	//VirtAddress stack = VirtAddress(new ubyte[0x1000].ptr) + 0x1000;
	//switchToUserMode(cast(ulong)&userspace, stack.Int);

	BasicShell bs = new BasicShell();
	bs.MainLoop();

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
	GetKernelPaging.Install();

	scr.Writeln("Heap initializing...");
	GetKernelHeap;

	scr.Writeln("PCI initializing...");
	GetPCI;

	scr.Writeln("Initrd initializing...");
	LoadInitrd();

	scr.Writeln("BGA initializing...");
	GetBGA.Init(new PSF(cast(FileNode)rootFS.Root.FindNode("/Data/Font/TTYFont.psf")));

	scr.Writeln("Scheduler initializing...");
	GetScheduler.Init();
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
