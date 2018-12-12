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
import stl.vmm.paging;
import hw.pci.pci;
import hw.cmos.cmos;
import arch.paging;
import stl.vmm.vmm;
import fs.tarfs;
import task.scheduler;
import syscall;

import powerd.api;

private immutable uint _major = __VERSION__ / 1000;
private immutable uint _minor = __VERSION__ % 1000;

private __gshared TarFSBlockDevice _blockDevice;
private __gshared TarFSSuperNode* _superNode;
/// The initrd
__gshared FSNode* initrdFS;
__gshared size_t coresDone;

void kmainAP(size_t id) {
	import task.scheduler : Scheduler;
	import stl.spinlock : SpinLock;

	GDT.flush(id);
	IDT.flush();

	asm pure @trusted nothrow @nogc {
		sti;
	}

	LAPIC.setup();

	__gshared SpinLock spinLock;

	spinLock.lock();
	Scheduler.addCPUCore(id);
	SyscallHandler.init(Scheduler.getCPUInfo(id));
	coresDone++;
	spinLock.unlock();

	// This will let the AP start working on tasks
	// This call will never return!
	Scheduler.yield();
	Log.fatal("Core ", id, " is dead!");
}

extern (C) void kmain(PowerDAPI* papi) {
	assert(papi.magic == PowerDAPI.magicValue);
	preInit(papi);
	welcome();
	init(papi);
	asm pure @trusted nothrow @nogc {
		sti;
	}
	initFS(papi.getModule("tarfs"));

	{
		coresDone++; // Main Core
		papi.toLoader.mainAP = &kmainAP;
		papi.toLoader.done = true;
		while (papi.cpus.cpuThreads.length != coresDone) {
			LAPIC.sleep(500);
		}
	}

	Scheduler.isEnabled = false;

	size_t counter;
	while (true) {
		const string c = "\xB0\xB1\xB2\xDB";
		const size_t cl = c.length;
		VGA.color = CGASlotColor(CGAColor.yellow, CGAColor.darkGrey);
		VGA.x = 0;
		VGA.y = 23;
		counter++;

		size_t v = counter;

		size_t pad0 = 80 / 2 - 20 / 2;
		foreach (i; 0 .. pad0)
			VGA.write(' ');

		foreach (i; 0 .. 20) {
			VGA.write(c[v % cl]);
			v /= cl;
		}
		foreach (i; 0 .. pad0)
			VGA.write(' ');

		asm @trusted nothrow @nogc {
			// pause;
			//db 0xf3, 0x90;
			hlt;
		}
	}

	string initFile = "/bin/init";
	TarFSNode* initNode = cast(TarFSNode*)initrdFS.findNode(initFile);
	if (!initNode)
		Log.fatal("'", initFile, "' is missing, boot halted!");

	{
		import stl.elf64;

		ELF64 init = ELF64(VirtMemoryRange.fromArray(initNode.data));
		*VirtAddress(0).ptr!size_t = 0x1337;

		if (!init.isValid)
			Log.fatal("'", initFile, "' is not a ELF, boot halted!");
	}

	VGA.color = CGASlotColor(CGAColor.red, CGAColor.yellow);
	VGA.writeln("kmain functions has exited!");
	Log.error("kmain functions has exited!");
	while (true) {
	}
}

void preInit(PowerDAPI* papi) {
	COM.init();
	VGA.init(papi.screenX, papi.screenY);
	VGA.color = CGASlotColor(CGAColor.lightCyan, CGAColor.black);

	// dfmt off
	VGA.writeln("
\xC9\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xBB
\xBA Welcome to the PowerNex Kernel \xBA
\xC8\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xCD\xBC");
	Log.info("
╔════════════════════════════════╗
║ Welcome to the PowerNex Kernel ║
╚════════════════════════════════╝");
	// dfmt on

	{
		import stl.elf64;

		auto elf = &papi.kernelELF;
		const(ELF64SectionHeader)* symtab, strtab;
		foreach (const ref ELF64SectionHeader section; elf.sectionHeaders) {
			if (elf.lookUpSectionName(section.name) == ".symtab")
				symtab = &section;
			else if (elf.lookUpSectionName(section.name) == ".strtab")
				strtab = &section;
		}

		// TODO: probably allocate space for these. These will break when the loader is unmapped! (probably)
		ELF64Symbol[] symbols = (elf.elfData.start + symtab.offset).ptr!ELF64Symbol[0 .. symtab.size / ELF64Symbol.sizeof];
		char[] strings = (elf.elfData.start + strtab.offset).ptr!char[0 .. strtab.size];

		Log.setSymbolMap(symbols, strings);
	}

	VGA.writeln("LAPIC initializing...");
	Log.info("LAPIC initializing...");
	LAPIC.init(papi.cpus.x2APIC, papi.cpus.lapicAddress, papi.cpus.cpuBusFreq);
	LAPIC.setup();

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

	Heap.init(makeAddress(500, 0, 0, 0));

	VGA.writeln("CMOS initializing...");
	Log.info("CMOS initializing...");
	CMOS.init(papi.acpi.century);

	VGA.writeln("Keyboard initializing...");
	Log.info("Keyboard initializing...");
	PS2Keyboard.init();

	VGA.writeln("PCI initializing...");
	Log.info("PCI initializing...");
	PCI.init();

	VGA.writeln("Scheduler initializing...");
	Log.info("Scheduler initializing...");
	Scheduler.init(papi.kernelStack);

	VGA.writeln("Syscall initializing...");
	Log.info("Syscall initializing...");
	SyscallHandler.init(Scheduler.getCPUInfo(0));
}

void initFS(Module* disk) @trusted {
	_blockDevice = TarFSBlockDevice(disk.memory.toVirtual);
	_superNode = newStruct!TarFSSuperNode(&_blockDevice);

	initrdFS = _superNode.base.getNode(0);
}
