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

static private immutable uint _major = __VERSION__ / 1000;
static private immutable uint _minor = __VERSION__ % 1000;

private void outputBoth(Args...)(Args args, string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__) @trusted {
	import stl.io.vga : VGA;
	import stl.io.log : Log;
	import stl.arch.amd64.msr : MSR;
	import stl.text : HexInt;

	if (MSR.fs) {
		import powerd.api.cpu : CPUThread;

		if (auto _ = currentThread) {
			VGA.writeln('<', HexInt(_.id), "> ", args);
			Log.info!(char, HexInt, char[2], Args)('<', HexInt(_.id), "> ", args, file, func, line);
			return;
		}
	}

	VGA.writeln(args);
	Log.info!(Args)(args, file, func, line);
}

__gshared VirtAddress apStackLoc = _makeAddress(0, 2, 0, 0);

extern (C) VirtAddress newStackAP() @trusted {
	if (!Paging.map(apStackLoc, PhysAddress(), VMPageFlags.present | VMPageFlags.writable | VMPageFlags.execute))
		return VirtAddress();

	auto stack = apStackLoc + 0x1000;
	apStackLoc += 0x1000 * 2; // As protection

	{
		import stl.arch.amd64.lapic : LAPIC;

		size_t id = LAPIC.getCurrentID();
		outputBoth("AP ", id, " stack is: ", stack);
	}
	return stack;
}

///
extern (C) ulong mainAP() @safe {
	import powerd.api : getPowerDAPI;
	import powerd.api.cpu : CPUThread;
	import stl.arch.amd64.lapic : LAPIC;
	import stl.io.log : Log;
	import data.tls : TLS;
	import stl.arch.amd64.gdt : GDT;
	import stl.arch.amd64.idt : IDT;
	import arch.amd64.paging : Paging;

	GDT.flush();
	IDT.flush();

	LAPIC.setup();

	TLS.aquireTLS();
	size_t id = LAPIC.getCurrentID();
	currentThread = &getPowerDAPI.cpus.cpuThreads[id];

	outputBoth("AP ", id, " has successfully booted!");

	currentThread.state = CPUThread.State.on;

	while (true) {
	}
}

import powerd.api.cpu : CPUThread;

CPUThread* currentThread; /// The current threads structure

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
	import stl.elf64 : ELF64, ELFInstance;
	import data.multiboot2 : Multiboot2;
	import data.tls : TLS;
	import stl.arch.amd64.com : COM;
	import stl.io.vga : VGA;
	import stl.io.log : Log;
	import stl.vmm.frameallocator : FrameAllocator;
	import stl.vmm.heap : Heap;

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

	Heap.init();
	TLS.aquireTLS();

	Multiboot2.parse();

	if (auto _ = Multiboot2.rsdpNew)
		ACPI.initNew(_);
	else if (auto _ = Multiboot2.rsdpOld)
		ACPI.initOld(_);
	else
		Log.fatal("No RSDP entry in the multiboot2 structure!");

	currentThread = &getPowerDAPI.cpus.cpuThreads[0];

	IOAPIC.analyze();

	auto kernelModule = Multiboot2.getModule("kernel");
	outputBoth("Kernel module: [", kernelModule.start, "-", kernelModule.end, "]");
	ELF64 kernelELF = ELF64(kernelModule);
	ELFInstance kernel; // = kernelELF.aquireInstance();

	outputBoth("kernel.main: ", VirtAddress(kernel.main));
	outputBoth("kernel.ctors: ");
	foreach (idx, ctor; kernel.ctors)
		outputBoth("\t", idx, ": ", VirtAddress(ctor));

	LAPIC.init();
	IOAPIC.setupLoader();
	PIC.disable();
	LAPIC.calibrate();
	LAPIC.setup();

	outputBoth("CPU bus freq: ", LAPIC.cpuBusFreq / 1_000_000, ".", LAPIC.cpuBusFreq % 1_000_000, " Mhz");

	// Init data
	SMP.init();
	outputBoth("SMP.init DONE!!!!!!!");

	// Setup more info data
	// freeData = Heap.lastAddress(); ?

	outputBoth("Kernel.ctors.length: ", kernel.ctors.length);
	() @trusted{
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

	() @trusted{ //
		auto papi = &getPowerDAPI();
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
		size_t output = kernel.main(papi); // TODO: Call this and set return address to 0
		//outputBoth("Main function returned: ", output.VirtAddress);
		assert(0, "Kernel main function returned! This should never ever happen!");
	}();

	outputBoth("Reached end of main! Shutting down in 2 seconds.");
	LAPIC.sleep(2000);

	ACPI.shutdown();

	return 0;
}
