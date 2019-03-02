module kmain;

import stl.arch.amd64.com;
import stl.io.log;
import stl.io.vga;
import stl.arch.amd64.gdt;
import stl.arch.amd64.idt;
import stl.arch.amd64.lapic;
import stl.arch.amd64.tsc : TSC;
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
import task.thread;
import syscall;
import stl.elf64;

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

private __gshared PowerDAPI _powerdAPI;
@property PowerDAPI* powerdAPI() {
	return &_powerdAPI;
}

@property PowerDAPI* powerdAPI(PowerDAPI* papi) {
	memcpy(&_powerdAPI, papi, PowerDAPI.sizeof);
	return &_powerdAPI;
}

extern (C) void kmain(PowerDAPI* papi) {
	assert(papi.magic == PowerDAPI.magicValue);
	powerdAPI = papi;
	preInit(papi);
	welcome();
	init(papi);
	initFS(papi.getModule("tarfs"));

	{
		coresDone++; // Main Core
		papi.toLoader.mainAP = &kmainAP;
		papi.toLoader.done = true;
		while (papi.cpus.cpuThreads.length != coresDone) {
			TSC.sleep(500);
		}
	}

	Scheduler.isEnabled = true;

	size_t counter;
	while (false) {
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

	version (none) {
		import arch.amd64.bga : BGA;

		BGA.init();
	}

	string initFile = "/binaries/init";
	TarFSNode* initNode = cast(TarFSNode*)initrdFS.findNode(initFile);
	if (!initNode)
		Log.fatal("'", initFile, "' is missing, boot halted!");

	{
		import stl.elf64;
		import task.thread;
		import stl.arch.amd64.msr;

		ELF64 init = ELF64(VirtMemoryRange.fromArray(initNode.data));

		if (!init.isValid)
			Log.fatal("'", initFile, "' is not a ELF, boot halted!");

		getKernelPaging.dump();

		VMThread* thread = Scheduler.getCurrentThread;
		VMProcess* process = newStruct!VMProcess(PhysAddress());
		thread.process = process;
		process.bind();

		ELFInstance initELF = instantiateELF(thread, init);

		void outputBoth(Args...)(Args args, string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__) @trusted {
			import stl.io.vga : VGA;
			import stl.io.log : Log;

			VGA.writeln(args);
			Log.info!(Args)(args, file, func, line);
		}

		outputBoth("initELF.main: ", VirtAddress(initELF.main));
		outputBoth("initELF.ctors: ");
		foreach (idx, ctor; initELF.ctors)
			outputBoth("\t", idx, ": ", VirtAddress(ctor));

		outputBoth("initELF.dtors: ");
		foreach (idx, dtor; initELF.dtors)
			outputBoth("\t", idx, ": ", VirtAddress(dtor));

		// TODO: Have a ld.so kinda of system that runs this in usermode, not in kernelmode
		() @trusted {
			foreach (ctor; initELF.ctors) {
				outputBoth("\t Running: ", VirtAddress(ctor));
				ctor();
			}
		}();

		auto stack = newUserStack(thread);

		VirtAddress set(T)(ref VirtAddress stack, T value) {
			import stl.trait : Unqual;

			auto size = T.sizeof;
			size = (size + 7) & ~7;
			stack -= size;
			*stack.ptr!(Unqual!T) = value;
			return stack;
		}

		VirtAddress setArray(T)(ref VirtAddress stack, T[] value) {
			import stl.trait : Unqual;

			auto size = T.sizeof * value.length;
			size = (size + 7) & ~7;
			stack -= size;
			stack.array!(Unqual!T)(value.length)[] = value[];
			return stack;
		}

		size_t[4] argvArray = [
			setArray(stack, "/binaries/init\0").num, setArray(stack, "1\0").num, setArray(stack, "2\0").num, setArray(stack, "three\0").num
		];

		auto switchToUserMode = &.switchToUserMode;
		auto main = initELF.main;
		auto argc = argvArray.length;
		auto argv = setArray(stack, argvArray).ptr;
		auto stackPtr = stack.ptr;

		thread.name = initFile;
		thread.image.elfImage = init;
		thread.threadState.tls = TLS.init(thread);
		MSR.fs = thread.threadState.tls.VirtAddress;
		thread.image.symbols = initELF.symbols;
		thread.image.symbolStrings = initELF.symbolStrings;
		Log.setUserspaceSymbolMap(thread.name, thread.image.symbols, thread.image.symbolStrings);

		outputBoth("Transferring control to the init elf, Good luck!");

		GDT.setRSP0(0, thread.kernelStack);

		SyscallHandler.setKernelStack(Scheduler.getCPUInfo(0));

		size_t fsVal = thread.threadState.tls.VirtAddress.num;
		outputBoth("FsValue", fsVal.VirtAddress);

		asm @trusted nothrow @nogc {
			mov R8, fsVal;
			mov RAX, switchToUserMode;
			mov RDI, main;
			mov RSI, stackPtr;
			mov RDX, argc;
			mov RCX, argv;
			jmp RAX;
		}
	}

	VGA.color = CGASlotColor(CGAColor.red, CGAColor.yellow);
	VGA.writeln("kmain functions has exited!");
	Log.error("kmain functions has exited!");
	while (true) {
	}
}

extern extern (C) void switchToUserMode();
extern (C) VirtAddress newUserStack(VMThread* thread) @trusted {
	VirtAddress stack = makeAddress(255, 511, 511, 511);
	foreach (i; 0 .. 0x10) {
		if (auto error = thread.process.mapFreeMemory(thread, stack - 0x1000 * i, VMPageFlags.present | VMPageFlags.writable | VMPageFlags.user)) {
			Log.error("Failed to map a userstack!: ", error);
			return VirtAddress();
		}
	}
	return stack + 0x1000;
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

		//Log.setSymbolMap(symbols, strings);
	}

	VGA.writeln("LAPIC initializing...");
	Log.info("LAPIC initializing...");
	LAPIC.init(papi.cpus.x2APIC, papi.cpus.lapicAddress, papi.cpus.cpuBusFreq);
	LAPIC.setup();

	VGA.writeln("TSC initializing...");
	Log.info("TSC initializing...");
	TSC.frequency = papi.cpus.tscFreq;

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
	VirtAddress initRD = makeAddress(510, 0, 2, 0);
	PhysAddress start = (disk.memory.start + 0xFFF) & ~0xFFF;
	size_t pages = ((disk.memory.size + 0xFFF) & ~0xFFF) / 0x1000;
	Log.info("disk.memory: [", disk.memory.start, " .. ", disk.memory.end, "]");
	Log.info("Mapping [", initRD, " .. ", initRD + pages * 0x1000, "] to [", start, " .. ", start + pages * 0x1000, "]. Pages: ", pages);
	foreach (i; 0 .. pages)
		getKernelPaging().mapAddress(initRD + i * 0x1000, start + i * 0x1000, VMPageFlags.present | VMPageFlags.writable);

	initRD += disk.memory.start & 0xFFF;

	_blockDevice = TarFSBlockDevice(VirtMemoryRange(initRD, initRD + disk.memory.size));
	_superNode = newStruct!TarFSSuperNode(&_blockDevice);

	initrdFS = _superNode.base.getNode(0);
}

// TODO: Move to scheduler.d
///
struct ELFInstance {
	import powerd.api : PowerDAPI;

	int function(int argc, char** argv) @system main;
	size_t function() @system[] ctors;
	size_t function() @system[] dtors;

	ELF64Symbol[] symbols;
	const(char)[] symbolStrings;
}

ELFInstance instantiateELF(VMThread* thread, ref ELF64 elf) @safe {
	import stl.io.log : Log;
	import stl.vmm.frameallocator : FrameAllocator;
	import arch.amd64.paging : VMPageFlags;

	ELFInstance instance;
	instance.main = () @trusted { return cast(typeof(instance.main))elf.header.entry.ptr; }();

	foreach (ref ELF64ProgramHeader hdr; elf.programHeaders) {
		if (hdr.type != ELF64ProgramHeader.Type.load)
			continue;
		//TODO: Can't expect that this is aligned
		VirtAddress vAddr = hdr.vAddr;
		VirtAddress data = elf.elfData.start + hdr.offset;
		PhysAddress pData = thread.process.backend.getPhysAddress(data) + data.num & 0xFFF;

		Log.info("Mapping [", vAddr, " - ", vAddr + hdr.memsz, "] and copying [", data, " - ", data + hdr.memsz, "] to it.");
		FrameAllocator.markRange(pData, pData + hdr.memsz); // Probably not needed
		for (size_t offset; offset < hdr.memsz; offset += 0x1000) {
			import stl.number : min;

			VirtAddress addr = vAddr + offset;

			// Map with writable
			if (VMMappingError error = thread.process.mapFreeMemory(thread, addr & ~0xFFF, VMPageFlags.present | VMPageFlags.writable))
				Log.fatal(error, ": Failed to map ", addr, " (to be able to copy ", data + offset, " to it)");
		}

		vAddr.memcpy(data, hdr.filesz);
		(vAddr + hdr.filesz).memset(0, hdr.memsz - hdr.filesz);

		for (size_t offset; offset < hdr.memsz; offset += 0x1000) {
			VirtAddress addr = vAddr + offset;
			// Remapping with correct flags
			VMPageFlags flags = VMPageFlags.user;
			if (hdr.flags & ELF64ProgramHeader.Flags.r)
				flags |= VMPageFlags.present;
			if (hdr.flags & ELF64ProgramHeader.Flags.w)
				flags |= VMPageFlags.writable;
			if (hdr.flags & ELF64ProgramHeader.Flags.x)
				flags |= VMPageFlags.execute;

			if (VMMappingError error = thread.process.remap(thread, addr & ~0xFFF, thread.process.backend.getPhysAddress(addr), flags))
				Log.fatal(error, ": Failed to remap ", addr);
		}
	}

	alias getSectionRange = (string name) {
		foreach (ref ELF64SectionHeader section; elf.sectionHeaders)
			if (elf.lookUpSectionName(section.name) == name)
				return VirtMemoryRange(section.addr, section.addr + section.size).array!(size_t function() @system);
		return null;
	};

	instance.ctors = getSectionRange(".ctors");
	instance.dtors = getSectionRange(".dtors");

	const(ELF64SectionHeader)* symtab, strtab;
	foreach (const ref ELF64SectionHeader section; elf.sectionHeaders) {
		if (elf.lookUpSectionName(section.name) == ".symtab")
			symtab = &section;
		else if (elf.lookUpSectionName(section.name) == ".strtab")
			strtab = &section;
	}

	// TODO: probably allocate space for these. These will break when the loader is unmapped! (probably)
	() @trusted {
		instance.symbols = (elf.elfData.start + symtab.offset).ptr!ELF64Symbol[0 .. symtab.size / ELF64Symbol.sizeof];
		instance.symbolStrings = (elf.elfData.start + strtab.offset).ptr!(const(char))[0 .. strtab.size];
	}();

	return instance;
}
