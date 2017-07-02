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
	import arch.amd64.gdt : GDT;
	import arch.amd64.idt : IDT;
	import data.multiboot2 : Multiboot2;
	import data.tls : TLS;
	import io.vga : VGA;
	import io.log : Log;

	GDT.init();
	IDT.init();

	Log.init();
	VGA.init();

	outputBoth("Hello world from D!");
	outputBoth("\tCompiled using '", __VENDOR__, "', D version ", _major, ".", _minor);

	APIInfo.init();

	// TODO: Implement alternative UEFI loading
	Multiboot2.init();

	TLS.aquireTLS();

	Log.info("tlsTest: ", tlsTest, " tlsTest2: ", tlsTest2);
	tlsTest2 = tlsTest;
	tlsTest = "Works also!";
	Log.info("tlsTest: ", tlsTest, " tlsTest2: ", tlsTest2);

	// Paging.init();
	// Heap.init();

	// ACPI.init();
	// IOAPIC.init();

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

	return 0;
}
