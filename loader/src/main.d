/**
 * The main entrypoint of the loader.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module main;

static private immutable uint _major = __VERSION__ / 1000;
static private immutable uint _minor = __VERSION__ % 1000;

private void outputBoth(Args...)(Args args) @safe {
	import io.vga : VGA;
	import io.log : Log;

	VGA.writeln(args);
	Log.info(args);
}

string tlsTest = "Works!";
string tlsTest2;

///
extern (C) ulong main() @safe {
	import api : APIInfo;
	import arch.amd64.acpi : ACPI;
	import arch.amd64.gdt : GDT;
	import arch.amd64.idt : IDT;
	import arch.amd64.ioapic : IOAPIC;
	import arch.amd64.paging : Paging;
	import arch.amd64.pit : PIT;
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

	TLS.aquireTLS();

	IOAPIC.analyze();

	// auto kernelModule = Multiboot.getKernel();
	// Kernel.verify(kernelModule);
	// ELF64 kernelELF = ELF64(kernel);
	// kernel = Kernel.process(kernelELF);

	// LAPIC.init();
	// IOAPIC.setup();
	// PIC.init();

	// LAPIC.calibrate();

	// Init data
	// SMP.init();

	// IDT.setup(kernel.idtSettings); ?
	// IOAPIC.setup(kernel.idtSettings); ?

	// Syscall.init();

	// Paging.map(kernel);

	// Setup more info data
	// freeData = Heap.lastAddress(); ?

	// Turn on AP
	// kernel.jmp();

	outputBoth("Reached end of main! Shutting down in 2 seconds.");
	PIT.sleep(2000);
	ACPI.shutdown();

	return 0;
}
