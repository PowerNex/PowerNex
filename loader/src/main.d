/**
 * The main entrypoint of the loader.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module main;

import data.address;

static private immutable uint _major = __VERSION__ / 1000;
static private immutable uint _minor = __VERSION__ % 1000;

private void outputBoth(string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__, Args...)(Args args) @trusted {
	import io.vga : VGA;
	import io.log : Log;
	import arch.amd64.msr : MSR;
	import data.text : HexInt;

	if (MSR.fs) {
		import api.cpu : CPUThread;

		if (auto _ = currentThread) {
			VGA.writeln('<', HexInt(_.id), "> ", args);
			Log.info!(file, func, line)('<', HexInt(_.id), "> ", args);
			return;
		}
	}

	VGA.writeln(args);
	Log.info!(file, func, line)(args);
}

__gshared VirtAddress apStackLoc = from!"arch.amd64.paging"._makeAddress(0, 2, 0, 0);

extern (C) VirtAddress newStackAP() @trusted {
	import arch.amd64.paging : Paging, PageFlags;

	if (!Paging.map(apStackLoc, PhysAddress(), PageFlags.present | PageFlags.writable | PageFlags.execute))
		return VirtAddress();

	auto stack = apStackLoc + 0x1000;
	apStackLoc += 0x1000 * 2; // As protection

	{
		import arch.amd64.lapic : LAPIC;

		size_t id = LAPIC.getCurrentID();
		outputBoth("AP ", id, " stack is: ", stack);
	}
	return stack;
}

///
extern (C) ulong mainAP() @safe {
	import api : getPowerDAPI;
	import api.cpu : CPUThread;
	import arch.amd64.lapic : LAPIC;
	import io.log : Log;
	import data.tls : TLS;
	import arch.amd64.gdt : GDT;
	import arch.amd64.idt : IDT;
	import arch.amd64.paging : Paging;

	GDT.flush();
	IDT.flush();
	Paging.init();

	LAPIC.setup();

	TLS.aquireTLS();
	size_t id = LAPIC.getCurrentID();
	currentThread = &getPowerDAPI.cpus.cpuThreads[id];

	outputBoth("AP ", id, " has successfully booted!");

	currentThread.state = CPUThread.State.on;

	while (true) {
	}
}

from!"api.cpu".CPUThread* currentThread; /// The current threads structure

///
extern (C) ulong main() @safe {
	import api : getPowerDAPI;
	import arch.amd64.acpi : ACPI;
	import arch.amd64.gdt : GDT;
	import arch.amd64.idt : IDT;
	import arch.amd64.lapic : LAPIC;
	import arch.amd64.ioapic : IOAPIC;
	import arch.amd64.paging : Paging;
	import arch.amd64.pic : PIC;
	import arch.amd64.pit : PIT;
	import arch.amd64.smp : SMP;
	import data.elf64 : ELF64, ELFInstance;
	import data.multiboot2 : Multiboot2;
	import data.tls : TLS;
	import io.vga : VGA;
	import io.log : Log;
	import memory.frameallocator : FrameAllocator;
	import memory.heap : Heap;

	GDT.init();
	IDT.init();

	PIT.init();

	Log.init();
	VGA.init();

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

	Paging.init();
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
	ELFInstance kernel = kernelELF.aquireInstance();

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
	int output = kernel.main(0, null);
	outputBoth("Main function returned: ", output.PhysAddress32);

	outputBoth("Reached end of main! Shutting down in 2 seconds.");
	LAPIC.sleep(2000);

	ACPI.shutdown();

	return 0;
}
