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

void kmainAP(size_t id) {
	import task.scheduler : Scheduler;

	asm pure nothrow {
		sti;
	}

	GDT.flush(id);
	IDT.flush();
	LAPIC.setup();

	Scheduler.addCPUCore(id);
	SyscallHandler.init(Scheduler.getCPUInfo(id));

	while (true) {
		asm @trusted nothrow @nogc {
			// pause;
			db 0xf3, 0x90;
		}
	}
}

extern (C) void kmain(PowerDAPI* papi) {
	assert(papi.magic == PowerDAPI.magicValue);
	preInit(papi);
	welcome();
	init(papi);
	asm pure nothrow {
		sti;
	}
	initFS(papi.getModule("tarfs"));

	{
		papi.toLoader.mainAP = &kmainAP;
		papi.toLoader.done = true;
		while (true) {
			LAPIC.sleep(500);
			asm @trusted nothrow @nogc {
				// pause;
				db 0xf3, 0x90;
			}
			Scheduler.cpuInfoMutex.lock();
			bool res = Scheduler.coresActive == papi.cpus.cpuThreads.length;
			Scheduler.cpuInfoMutex.unlock();
			if (res)
				break;
		}
	}

	Scheduler.isEnabled = true;

	size_t counter;
	while (true) {
		VGA.writeln("counter: ", counter++);
		asm @trusted nothrow @nogc {
			// pause;
			db 0xf3, 0x90;
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
