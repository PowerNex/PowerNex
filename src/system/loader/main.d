/**
 * The main entrypoint of the loader.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module main;

import stl.address;

import arch.amd64.paging;
import stl.vmm.paging;
import stl.elf64;

static private immutable uint _major = __VERSION__ / 1000;
static private immutable uint _minor = __VERSION__ % 1000;

private void outputBoth(Args...)(Args args, string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__) @trusted {
	import stl.io.vga : VGA;
	import stl.io.log : Log;
	import stl.arch.amd64.msr : MSR;
	import stl.text : HexInt;

	VGA.writeln(args);
	Log.info!(Args)(args, file, func, line);
}

__gshared VirtAddress apStackLoc = _makeAddress(510, 1, 0, 0);

extern (C) VirtAddress newStackAP() @trusted {
	import stl.io.log : Log;

	if (apStackLoc + 0x10_000 > _makeAddress(510, 2, 0, 0))
		Log.fatal("TOO MANY CORES! (How can you have ", (0x1000 / 0x10) * 512, " cores!?)");

	static foreach (i; 0 .. 0x10)
		if (!Paging.map(apStackLoc + 0x1000 * i, PhysAddress(), VMPageFlags.present | VMPageFlags.writable))
			return VirtAddress();

	auto stack = apStackLoc + 0x10_000;
	apStackLoc += 0x10_000;

	{
		import stl.arch.amd64.lapic : LAPIC;

		size_t id = LAPIC.getCurrentID();
		outputBoth("AP ", id, " stack is: ", stack);
	}
	return stack;
}

///
extern (C) void mainAP() @safe {
	import powerd.api : getPowerDAPI;
	import powerd.api.cpu : CPUThread;
	import stl.arch.amd64.lapic : LAPIC;
	import stl.io.log : Log;
	import data.tls : TLS;
	import stl.arch.amd64.gdt : GDT;
	import stl.arch.amd64.idt : IDT;
	import arch.amd64.paging : Paging;

	size_t id = LAPIC.getCurrentID();
	GDT.flush(id);
	IDT.flush();

	LAPIC.setup();

	TLS.aquireTLS();
	currentThread = &getPowerDAPI.cpus.cpuThreads[id];

	outputBoth("AP ", id, " has successfully booted!");

	currentThread.state = CPUThread.State.on;

	auto done = &getPowerDAPI().toLoader.done;
	while (!(*done)) {
		asm pure @trusted nothrow @nogc {
			// pause;
			db 0xf3, 0x90;
		}
	}

	() @trusted { //
		getPowerDAPI().toLoader.mainAP(id);
	}();

	while (true) {
	}
}

import powerd.api.cpu : CPUThread;

CPUThread* currentThread; /// The current threads structure

///
@safe struct KernelELFInstance {
	import powerd.api : PowerDAPI;

	size_t function(PowerDAPI* powerDAPI) @system main;
	size_t function() @system[] ctors;
}

KernelELFInstance instantiateELF(ref ELF64 elf) @safe {
	import stl.io.log : Log;
	import stl.vmm.frameallocator : FrameAllocator;
	import arch.amd64.paging : Paging, VMPageFlags;

	KernelELFInstance instance;
	instance.main = () @trusted { return cast(typeof(instance.main))elf.header.entry.ptr; }();

	foreach (ref ELF64ProgramHeader hdr; elf.programHeaders) {
		if (hdr.type != ELF64ProgramHeader.Type.load)
			continue;

		VirtAddress vAddr = hdr.vAddr;
		VirtAddress data = elf.elfData.start + hdr.offset;
		PhysAddress pData = PhysAddress(elf.elfData.start) + hdr.offset;

		Log.info("Mapping [", vAddr, " - ", vAddr + hdr.memsz, "] to [", pData, " - ", pData + hdr.memsz, "]");
		FrameAllocator.markRange(pData, pData + hdr.memsz);
		for (size_t offset; offset < hdr.memsz; offset += 0x1000) {
			import stl.number : min;

			VirtAddress addr = vAddr + offset;
			PhysAddress pAddr = pData + offset;

			// Map with writable
			if (!Paging.map(addr, PhysAddress(), VMPageFlags.present | VMPageFlags.writable, false))
				Log.fatal("Failed to map ", addr, "( to ", pAddr, ")");

			// Copying the data over, and zeroing the excess
			size_t dataLen = (offset > hdr.filesz) ? 0 : min(hdr.filesz - offset, 0x1000);
			size_t zeroLen = min(0x1000 - dataLen, hdr.memsz - offset);

			addr.memcpy(data + offset, dataLen);
			(addr + dataLen).memset(0, zeroLen);

			// Remapping with correct flags
			VMPageFlags flags;
			if (hdr.flags & ELF64ProgramHeader.Flags.r)
				flags |= VMPageFlags.present;
			if (hdr.flags & ELF64ProgramHeader.Flags.w)
				flags |= VMPageFlags.writable;
			if (hdr.flags & ELF64ProgramHeader.Flags.x)
				flags |= VMPageFlags.execute;

			if (!Paging.remap(addr, PhysAddress(), flags))
				Log.fatal("Failed to remap ", addr);
		}
	}

	alias getCtors = () {
		foreach (ref ELF64SectionHeader section; elf.sectionHeaders)
			if (elf.lookUpSectionName(section.name) == ".ctors")
				return VirtMemoryRange(section.addr, section.addr + section.size).array!(size_t function() @system);
		return null;
	};

	instance.ctors = getCtors();

	return instance;
}

///
extern (C) ulong main() @safe {
	import powerd.api : getPowerDAPI;
	import arch.amd64.acpi : ACPI;
	import stl.arch.amd64.gdt : GDT;
	import stl.arch.amd64.idt : IDT;
	import stl.arch.amd64.lapic : LAPIC;
	import stl.arch.amd64.ioapic : IOAPIC;
	import arch.amd64.paging : Paging;
	import arch.amd64.pic : PIC;
	import arch.amd64.pit : PIT;
	import arch.amd64.smp : SMP;
	import stl.elf64 : ELF64;
	import data.multiboot2 : Multiboot2;
	import data.tls : TLS;
	import stl.arch.amd64.com : COM;
	import stl.io.vga : VGA;
	import stl.io.log : Log;
	import stl.vmm.frameallocator : FrameAllocator;
	import stl.vmm.heap : Heap;
	import stl.arch.amd64.msr : MSR;

	COM.init();
	VGA.init();

	PIT.init();

	GDT.init();
	IDT.init();

	outputBoth("Hello world from D!");
	outputBoth("\tCompiled using '", __VENDOR__, "', D version ", _major, ".", _minor);

	{
		auto _ = getPowerDAPI.version_;
		outputBoth("Loader version: ", _.major, ".", _.minor, ".", _.patch);
	}

	FrameAllocator.init();
	// TODO: Implement alternative UEFI loading
	// Note this will initialize other modules
	Multiboot2.earlyParse();
	FrameAllocator.preAllocateFrames();

	Heap.init(makeAddress(0, 1, 0, 0));
	TLS.aquireTLS();

	Multiboot2.parse();

	if (auto _ = Multiboot2.rsdpNew)
		ACPI.initNew(_);
	else if (auto _ = Multiboot2.rsdpOld)
		ACPI.initOld(_);
	else
		Log.fatal("No RSDP entry in the multiboot2 structure!");

	() @trusted { Log.warning("ct: ", &(getPowerDAPI.cpus.cpuThreads[0])); }();
	currentThread = &getPowerDAPI.cpus.cpuThreads[0];

	() @trusted { Log.warning("currentThread: ", currentThread); }();

	IOAPIC.analyze();

	LAPIC.init();
	IOAPIC.setupLoader();
	PIC.disable();
	LAPIC.calibrate();
	LAPIC.setup();

	outputBoth("CPU bus freq: ", LAPIC.cpuBusFreq / 1_000_000, ".", LAPIC.cpuBusFreq % 1_000_000, " Mhz");

	// Init data
	SMP.init();
	outputBoth("SMP.init DONE!!!!!!!");

	auto kernelModule = Multiboot2.getModule("kernel");
	outputBoth("Kernel module: [", kernelModule.start, "-", kernelModule.end, "]");

	auto kELF = &getPowerDAPI.kernelELF;
	*kELF = ELF64(kernelModule.toVirtual);
	if (!kELF.isValid)
		Log.fatal("Kernel ELF is not valid!");
	KernelELFInstance kernel = instantiateELF(*kELF);

	outputBoth("kernel.main: ", VirtAddress(kernel.main));
	outputBoth("kernel.ctors: ");
	foreach (idx, ctor; kernel.ctors)
		outputBoth("\t", idx, ": ", VirtAddress(ctor));

	// Setup more info data
	// freeData = Heap.lastAddress(); ?

	outputBoth("Kernel.ctors.length: ", kernel.ctors.length);
	() @trusted {
		foreach (ctor; kernel.ctors) {
			outputBoth("\t Running: ", VirtAddress(ctor));
			if (VirtAddress(ctor) < 0xFFFFFFFF_80000000)
				Log.fatal("ctor is invalid!");
			ctor();
		}
	}();
	outputBoth("Kernels main is located at: ", VirtAddress(kernel.main));
	if (VirtAddress(kernel.main) < 0xFFFFFFFF_80000000)
		Log.fatal("Main is invalid!");

	outputBoth("Transferring control to the kernel, Good luck!");

	auto main = kernel.main;
	auto stack = newStackAP().ptr!ubyte;
	auto papi = () @trusted { return &getPowerDAPI(); }();

	() @trusted { //
		papi.screenX = VGA.x;
		papi.screenY = VGA.y;

		{
			with (papi.memory) {
				maxFrames = FrameAllocator.maxFrames;
				usedFrames = FrameAllocator.usedFrames;
				bitmaps = FrameAllocator.bitmaps[];
				currentBitmapIdx = FrameAllocator.currentBitmapIdx;
			}
		}

		papi.kernelStack = VirtMemoryRange(VirtAddress(stack - 0x10_000), VirtAddress(stack));
	}();

	outputBoth("Main: ", cast(void*)main, "\tpAPI: ", cast(void*)papi, "\tStack: ", cast(void*)stack);

	asm pure @trusted nothrow @nogc {
		mov RDI, papi;
		mov RAX, main;
		mov RSP, stack;
		mov RBP, 0;
		push 0;
		jmp RAX;
	}
	assert(0, "Kernel main function returned! This should never ever happen!");
}

extern extern (C) void switchStackAndJump(void* func, void* arg0, void* stack) @trusted;
