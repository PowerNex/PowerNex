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

	VGA.writeln(args);
	Log.info!(file, func, line)(args);
}

///
extern (C) ulong mainAP() @safe {
	import api : APIInfo;
	import api.cpu : CPUThread;
	import arch.amd64.lapic : LAPIC;
	import io.log : Log;
	import data.tls : TLS;

	TLS.aquireTLS();
	size_t id = LAPIC.getCurrentID();
	CPUThread* currentThread = &APIInfo.cpus.cpuThreads[id];

	outputBoth("AP ", id, " has successfully booted!");

	currentThread.state = CPUThread.State.on;

	while (true) {
	}
}

// FIXME: If removed the loader crashes, please fix
string tlsTest = "Works!";
string tlsTest2;

///
extern (C) ulong main() @safe {
	import api : APIInfo;
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

	APIInfo.init();

	FrameAllocator.init();
	// TODO: Implement alternative UEFI loading
	// Note this will initialize other modules
	Multiboot2.init();
	FrameAllocator.preAllocateFrames();

	Paging.init();
	Heap.init();

	if (auto _ = Multiboot2.rsdpNew)
		ACPI.initNew(_);
	else if (auto _ = Multiboot2.rsdpOld)
		ACPI.initOld(_);
	else
		Log.fatal("No RSDP entry in the multiboot2 structure!");

	TLS.aquireTLS();

	IOAPIC.analyze();

	auto kernelModule = Multiboot2.getModule("kernel");
	outputBoth("Kernel module: [", kernelModule.start, "-", kernelModule.end, "]");
	ELF64 kernelELF = ELF64(kernelModule);
	ELFInstance kernel = kernelELF.aquireInstance();

	outputBoth("Kernel ctors: ", &kernel.ctors[0], ", size: ", kernel.ctors.length);
	() @trusted{
		foreach (ctor; kernel.ctors) {
			outputBoth("\t Running: ", ctor);
			ctor();
		}
	}();

	LAPIC.init();
	IOAPIC.setupLoader();
	PIC.disable();

	LAPIC.calibrate();
	LAPIC.setup();

	outputBoth("CPU bus freq: ", LAPIC.cpuBusFreq / 1_000_000, ".", LAPIC.cpuBusFreq % 1_000_000, " Mhz");

	// Init data
	SMP.init();

	// IDT.setup(kernel.idtSettings); ?
	// IOAPIC.setup(kernel.idtSettings); ?

	// Syscall.init();

	// Paging.map(kernel);

	// Setup more info data
	// freeData = Heap.lastAddress(); ?

	// Turn on AP
	// kernel.jmp();

	outputBoth("Kernels main is located at: ", VirtAddress(kernel.main));
	int output = kernel.main(0, null);
	outputBoth("Main function returned: ", output.PhysAddress32);

	outputBoth("Reached end of main! Shutting down in 2 seconds.");
	LAPIC.sleep(2000);

	ACPI.shutdown();

	return 0;
}
