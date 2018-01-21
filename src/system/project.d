module src.system.project;

void setupProject() {
	initLoader();
	initKernel();
}

private:
import build;
import src.buildlib;

immutable {
	string dCompilerArgs = " -m64 -dip25 -dip1000 -fPIC -betterC -dw -color=on -debug -c -g -of$out$ $in$ -version=bare_metal -debug=allocations -defaultlib= -debuglib=";
	string aCompilerArgs = " --divide --64 -o $out$ $in$";
	string linkerArgs = " -o $out$ -z max-page-size=0x1000 $in$ -nostdlib";

	string dCompilerLoader = dCompilerPath ~ dCompilerArgs
		~ " -version=PowerD -Isrc/system/loader -Jsrc/system/loader -D -Dddocs/generated/loader -X -Xfdocs/loader.json";
	string aCompilerLoader = aCompilerPath ~ aCompilerArgs;
	string linkerLoader = linkerPath ~ linkerArgs ~ " -T src/system/loader/linker.ld";

	string dCompilerKernel = dCompilerPath ~ dCompilerArgs
		~ " -Isrc/system/kernel -Jsrc/system/kernel -D -Dddocs/generated/kernel -X -Xfdocs/kernel.json";
	string aCompilerKernel = aCompilerPath ~ aCompilerArgs;
	string linkerKernel = linkerPath ~ linkerArgs ~ " -T src/system/kernel/linker.ld";
}

void initLoader() {
	Project loader = new Project("PowerD", SemVer(0, 1, 337));
	with (loader) {
		// dfmt off
			auto dFiles = files!("src/system/loader/",
				"arch/amd64/aml.d",
				"arch/amd64/gdt.d",
				"arch/amd64/paging.d",
				"arch/amd64/pit.d",
				"arch/amd64/register.d",
				"arch/amd64/acpi.d",
				"arch/amd64/ioapic.d",
				"arch/amd64/msr.d",
				"arch/amd64/pic.d",
				"arch/amd64/idt.d",
				"arch/amd64/lapic.d",
				"arch/amd64/smp.d",
				"data/address.d",
				"data/bitfield.d",
				"data/multiboot2.d",
				"data/number.d",
				"data/range.d",
				"data/text.d",
				"data/vector.d",
				"data/tls.d",
				"data/elf64.d",
				"io/com.d",
				"io/ioport.d",
				"io/vga.d",
				"io/log.d",
				"util/spinlock.d",
				"util/trait.d",
				"api/cpu.d",
				"api/package.d",
				"api/acpi.d",
				"invariant.d",
				"memory/frameallocator.d",
				"memory/heap.d",
				"object.d",
				"utils.d",
				"main.d"
			);

			auto aFiles = files!("src/system/loader/",
				"arch/amd64/wrappers.S",
				"util/spinlock_asm.S",
				"init16.S",
				"init64.S",
				"init32.S",
			);

			auto consoleFont = files!("data/disk/data/fonts/",
				"terminus/ter-v16n.psf",
				"terminus/ter-v16b.psf"
			);
			// dfmt on

		auto dCompiler = Processor.combine(dCompilerLoader);
		auto aCompiler = Processor.combine(aCompilerLoader);
		auto linker = Processor.combine(linkerLoader);

		outputs["powerd"] = linker("powerd.ldr", false, [dCompiler("dcode.o", false, dFiles, consoleFont),
				aCompiler("acode.o", false, aFiles)]);
	}
	registerProject(loader);
}

void initKernel() {
	Project kernel = new Project("PowerNex", SemVer(0, 0, 0));
	with (kernel) {
		// dfmt off
			auto dFiles = files!("src/system/kernel/",
				"acpi/rsdp.d",
				"arch/amd64/paging.d",
				"arch/paging.d",
				"bin/consolefont.d",
				"cpu/gdt.d",
				"cpu/msr.d",
				"cpu/pit.d",
				"cpu/tss.d",
				"cpu/idt.d",
				"data/address.d",
				"data/color.d",
				"data/container.d",
				"data/font.d",
				"data/linkedlist.d",
				"data/linker.d",
				"data/parameters.d",
				"data/psf.d",
				"data/range.d",
				"data/register.d",
				"data/screen.d",
				"data/string_.d",
				"data/textbuffer.d",
				"data/util.d",
				"data/bitfield.d",
				"data/bmpimage.d",
				"data/elf.d",
				"data/multiboot.d",
				"data/text.d",
				"data/utf.d",
				"fs/iofs/package.d",
				"fs/iofs/stdionode.d",
				"fs/mountnode.d",
				"fs/node.d",
				"fs/nullfs.d",
				"fs/package.d",
				"fs/tarfs.d",
				"hw/cmos/cmos.d",
				"hw/pci/pci.d",
				"hw/ps2/kbset.d",
				"hw/ps2/keyboard.d",
				"invariant.d",
				"io/com.d",
				"io/consolemanager.d",
				"io/port.d",
				"io/log.d",
				"io/textmode.d",
				"memory/allocator/kheapallocator.d",
				"memory/allocator/package.d",
				"memory/vmm.d",
				"memory/ptr.d",
				"memory/frameallocator.d",
				"memory/kheap.d",
				"system/syscallhandler.d",
				"system/utils.d",
				"system/syscall.d",
				"task/mutex/schedulemutex.d",
				"task/mutex/spinlockmutex.d",
				"task/scheduler.d",
				"task/process.d",
				"util/trait.d",
				"object.d",
				"kmain.d"
			);

			auto aFiles = files!("src/system/kernel/",
				"extra.S",
				"system/syscallhelper.S",
				"task/mutex/assembly.S",
				"task/task.S",
				"boot.S"
			);

			auto consoleFont = files!("disk/data/font/",
				"terminus/ter-v16n.psf",
				"terminus/ter-v16b.psf"
			);
			// dfmt on

		auto dCompiler = Processor.combine(dCompilerKernel);
		auto aCompiler = Processor.combine(aCompilerKernel);
		auto linker = Processor.combine(linkerKernel);

		outputs["powernex"] = linker("powernex.krl", false, [dCompiler("dcode.o", false, dFiles, consoleFont),
				aCompiler("acode.o", false, aFiles)]);
	}
	registerProject(kernel);
}
