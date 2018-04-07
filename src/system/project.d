module src.system.project;

void setupProject() {
	initSTL();
	initLoaderAPI();
	initLoader();
	initKernel();
}

private:
import build;
import src.buildlib;

immutable {
	string dCompilerArgs = " -m64 -dip25 -dip1000 -dip1008 -fPIC -betterC -dw -color=on -debug -c -g -of$out$ $in$ -version=bare_metal -debug=allocations -defaultlib= -debuglib= -Isrc/system/stl";
	string aCompilerArgs = " --divide --64 -o $out$ $in$";
	string linkerArgs = " -o $out$ -z max-page-size=0x1000 $in$ -nostdlib";
	string archiveArgs = " rcs $out$ $in$";

	string dCompilerLoader = dCompilerPath ~ dCompilerArgs
		~ " -version=PowerD -Isrc/system/loader -Jsrc/system/loader -Isrc/system/loader-api -D -Dddocs/generated/loader -X -Xfdocs/loader.json";
	string aCompilerLoader = aCompilerPath ~ aCompilerArgs;
	string linkerLoader = linkerPath ~ linkerArgs ~ " -T src/system/loader/linker.ld";

	string dCompilerKernel = dCompilerPath ~ dCompilerArgs
		~ " -Isrc/system/kernel -Jsrc/system/kernel -Isrc/system/loader-api -D -Dddocs/generated/kernel -X -Xfdocs/kernel.json";
	string aCompilerKernel = aCompilerPath ~ aCompilerArgs;
	string linkerKernel = linkerPath ~ linkerArgs ~ " -T src/system/kernel/linker.ld";
}

void initSTL() {
	Project loader = new Project("STL", SemVer(0, 1, 337));
	with (loader) {
		// dfmt off
		auto dFiles = files!("src/system/stl/",
			"stl/bitfield.d",
			"stl/number.d",
			"stl/range.d",
			"stl/vector.d",
			"stl/register.d",
			"stl/arch/amd64/msr.d",
			"stl/arch/amd64/com.d",
			"stl/arch/amd64/gdt.d",
			"stl/arch/amd64/idt.d",
			"stl/arch/amd64/ioapic.d",
			"stl/arch/amd64/ioport.d",
			"stl/arch/amd64/lapic.d",
			"stl/address.d",
			"stl/elf64.d",
			"stl/io/log.d",
			"stl/io/vga.d",
			"stl/spinlock.d",
			"stl/text.d",
			"stl/trait.d",
			"stl/utf.d",
			"stl/vtable.d",
			"stl/vmm/paging.d",
			"stl/vmm/vmm.d",
			"stl/vmm/frameallocator.d",
			"stl/vmm/heap.d",
			"object.d",
			"invariant.d"
		);

		auto aFiles = files!("src/system/stl/",
			"stl/arch/amd64/lapic_asm.S",
			"stl/spinlock_asm.S"
		);
		// dfmt on

		auto dCompiler = Processor.combine(
				dCompilerPath ~ dCompilerArgs ~ " -version=Target_" ~ name ~ " -Isrc/system/loader" ~ " -Isrc/system/loader-api");
		auto aCompiler = Processor.combine(aCompilerPath ~ aCompilerArgs);
		auto archive = Processor.combine(archivePath ~ archiveArgs);

		outputs["libstl"] = archive("libstl.a", false, [dCompiler("dcode.o", false, dFiles), aCompiler("acode.o", false, aFiles)]);
	}
	registerProject(loader);
}

void initLoaderAPI() {
	Project loader = new Project("LoaderAPI", SemVer(0, 1, 337));
	with (loader) {
		// dfmt off
		auto dFiles = files!("src/system/loader-api/",
			"powerd/api/acpi.d",
			"powerd/api/cpu.d",
			"powerd/api/memory.d",
			"powerd/api/package.d"
		);
		// dfmt on

		auto dCompiler = Processor.combine(dCompilerPath ~ dCompilerArgs ~ " -version=Target_" ~ name ~ " -Isrc/system/loader" ~ " -Isrc/system/loader-api");
		auto archive = Processor.combine(archivePath ~ archiveArgs);

		outputs["libloader-api"] = archive("libloader-api.a", false, [dCompiler("dcode.o", false, dFiles)]);
	}
	registerProject(loader);
}

void initLoader() {
	Project loader = new Project("PowerD", SemVer(0, 1, 337));
	with (loader) {
		auto stl = findDependency("STL");
		dependencies ~= stl;
		auto loaderAPI = findDependency("LoaderAPI");
		dependencies ~= loaderAPI;

		// dfmt off
		auto dFiles = files!("src/system/loader/",
			"arch/amd64/aml.d",
			"arch/amd64/pic.d",
			"arch/amd64/smp.d",
			"arch/amd64/acpi.d",
			"arch/amd64/paging.d",
			"arch/amd64/pit.d",
			"data/multiboot2.d",
			"data/tls.d",
			"utils.d",
			"main.d"
		);

		auto aFiles = files!("src/system/loader/",
			"arch/amd64/wrappers.S",
			"init16.S",
			"init32.S",
			"init64.S"
		);

		auto consoleFont = files!("data/disk/data/fonts/",
			"terminus/ter-v16n.psf",
			"terminus/ter-v16b.psf"
		);
		// dfmt on

		auto dCompiler = Processor.combine(dCompilerLoader ~ " -version=Target_" ~ name);
		auto aCompiler = Processor.combine(aCompilerLoader);
		auto linker = Processor.combine(linkerLoader);

		outputs["powerd"] = linker("powerd.ldr", false, [dCompiler("dcode.o", false, dFiles, consoleFont),
				aCompiler("acode.o", false, aFiles), stl.outputs["libstl"], loaderAPI.outputs["libloader-api"]]);
	}
	registerProject(loader);
}

void initKernel() {
	Project kernel = new Project("PowerNex", SemVer(0, 0, 0));
	with (kernel) {
		auto stl = findDependency("STL");
		dependencies ~= stl;
		auto loaderAPI = findDependency("LoaderAPI");
		dependencies ~= loaderAPI;

		// dfmt off
		auto dFiles = files!("src/system/kernel/",
			"arch/amd64/tss.d",
			"arch/amd64/paging.d",
			"arch/paging.d",
			"hw/cmos/cmos.d",
			"hw/pci/pci.d",
			"hw/ps2/kbset.d",
			"hw/ps2/keyboard.d",
			"fs/package.d",
			"fs/block.d",
			"fs/node.d",
			"fs/supernode.d",
			"fs/tarfs/package.d",
			"fs/tarfs/block.d",
			"fs/tarfs/node.d",
			"fs/tarfs/supernode.d",
			"kmain.d"
		);

		auto aFiles = files!("src/system/kernel/",
			"extra.S"
		);

		auto consoleFont = files!("disk/data/font/",
			"terminus/ter-v16n.psf",
			"terminus/ter-v16b.psf"
		);
		// dfmt on

		auto dCompiler = Processor.combine(dCompilerKernel ~ " -version=Target_" ~ name);
		auto aCompiler = Processor.combine(aCompilerKernel);
		auto linker = Processor.combine(linkerKernel);

		outputs["powernex"] = linker("powernex.krl", false, [dCompiler("dcode.o", false, dFiles, consoleFont),
				aCompiler("acode.o", false, aFiles), stl.outputs["libstl"], loaderAPI.outputs["libloader-api"]]);
	}
	registerProject(kernel);
}
