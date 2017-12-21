#!/usr/bin/rdmd
module build;

import utils.buildlib;

import std.algorithm;
import std.string;
import std.array;
import std.range;
import std.datetime : SysTime;
import std.file : DirEntry;

void setupProjects() {
	import std.format : format;

	auto nothing = Processor.combine("");
	auto cp = Processor.combine("cp --reflink=auto $in$ $out$");

	string dCompilerArgsLoader = "-m64 -dip25 -dip1000 -dw -color=on -debug -betterC -c -g -version=PowerD -Iloader/src -Jloader/src -Jdisk/ -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/loader -X -Xfdocs-loader.json -of$out$ $in$";
	string aCompilerArgsLoader = "--64 -o $out$ $in$";
	string linkerArgsLoader = "-o $out$ -z max-page-size=0x1000 $in$ -T loader/src/loader.ld -nostdlib";

	string dCompilerArgsKernel = "-m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -Ikernel/src -I%1$s/kernel/src -Jkernel/src -J%1$s/kernel/src -Jdisk/ -J%1$s/disk -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/kernel -X -Xfdocs-kernel.json -of$out$ $in$";
	string aCompilerArgsKernel = "--divide --64 -o $out$ $in$";
	string linkerArgsKernel = "-o $out$ -z max-page-size=0x1000 $in$ -T kernel/src/kernel.ld -nostdlib";

	{
		Project loader = new Project("PowerD", SemVer(0, 1, 337));
		with (loader) {
			// dfmt off
			auto dFiles = files!(
				"loader/src/arch/amd64/aml.d",
				"loader/src/arch/amd64/gdt.d",
				"loader/src/arch/amd64/paging.d",
				"loader/src/arch/amd64/pit.d",
				"loader/src/arch/amd64/register.d",
				"loader/src/arch/amd64/acpi.d",
				"loader/src/arch/amd64/ioapic.d",
				"loader/src/arch/amd64/msr.d",
				"loader/src/arch/amd64/pic.d",
				"loader/src/arch/amd64/idt.d",
				"loader/src/arch/amd64/lapic.d",
				"loader/src/arch/amd64/smp.d",
				"loader/src/data/address.d",
				"loader/src/data/bitfield.d",
				"loader/src/data/multiboot2.d",
				"loader/src/data/number.d",
				"loader/src/data/range.d",
				"loader/src/data/text.d",
				"loader/src/data/vector.d",
				"loader/src/data/tls.d",
				"loader/src/data/elf64.d",
				"loader/src/io/com.d",
				"loader/src/io/ioport.d",
				"loader/src/io/vga.d",
				"loader/src/io/log.d",
				"loader/src/util/spinlock.d",
				"loader/src/util/trait.d",
				"loader/src/api/cpu.d",
				"loader/src/api/package.d",
				"loader/src/api/acpi.d",
				"loader/src/invariant.d",
				"loader/src/memory/frameallocator.d",
				"loader/src/memory/heap.d",
				"loader/src/object.d",
				"loader/src/utils.d",
				"loader/src/main.d"
			);

			auto aFiles = files!(
				"loader/src/arch/amd64/wrappers.S",
				"loader/src/util/spinlock_asm.S",
				"loader/src/init16.S",
				"loader/src/init64.S",
				"loader/src/init32.S",
			);

			auto consoleFont = files!(
				"disk/data/font/terminus/ter-v16n.psf",
				"disk/data/font/terminus/ter-v16b.psf"
			);
			// dfmt on

			auto dCompiler = Processor.combine("cc/bin/powernex-dmd " ~ dCompilerArgsLoader);
			auto aCompiler = Processor.combine("cc/bin/x86_64-powernex-as " ~ aCompilerArgsLoader);
			auto linker = Processor.combine("cc/bin/x86_64-powernex-ld " ~ linkerArgsLoader);

			outputs["powerd"] = linker("disk/boot/powerd.ldr", false, [dCompiler("dcode.o", false, dFiles, consoleFont),
					aCompiler("acode.o", false, aFiles)]);
		}
		registerProject(loader);
	}

	{
		Project initrd = new Project("PowerNexOS-InitRD", SemVer(0, 0, 0));
		with (initrd) {
			// dfmt off
			auto initrdFiles = files!(
				"initrd/data/dlogo.bmp"
			);
			auto initrdDataDir = cp("initrd/data/", false, initrdFiles);
			auto initrdDir = nothing("initrd", false, null, [initrdDataDir]);
			// dfmt on

			auto makeInitrd = Processor.combine("tar -c --posix -f $out$ -C $in$ .");

			outputs["initrd"] = makeInitrd("disk/boot/powernex-initrd.dsk", false, [initrdDir]);
		}
		registerProject(initrd);
	}

	{
		Project kernel = new Project("PowerNex", SemVer(0, 0, 0));
		with (kernel) {
			// dfmt off
			auto dFiles = files!(
				"kernel/src/acpi/rsdp.d",
				"kernel/src/arch/amd64/paging.d",
				"kernel/src/arch/paging.d",
				"kernel/src/bin/consolefont.d",
				"kernel/src/cpu/gdt.d",
				"kernel/src/cpu/msr.d",
				"kernel/src/cpu/pit.d",
				"kernel/src/cpu/tss.d",
				"kernel/src/cpu/idt.d",
				"kernel/src/data/address.d",
				"kernel/src/data/color.d",
				"kernel/src/data/container.d",
				"kernel/src/data/font.d",
				"kernel/src/data/linkedlist.d",
				"kernel/src/data/linker.d",
				"kernel/src/data/parameters.d",
				"kernel/src/data/psf.d",
				"kernel/src/data/range.d",
				"kernel/src/data/register.d",
				"kernel/src/data/screen.d",
				"kernel/src/data/string_.d",
				"kernel/src/data/textbuffer.d",
				"kernel/src/data/util.d",
				"kernel/src/data/bitfield.d",
				"kernel/src/data/bmpimage.d",
				"kernel/src/data/elf.d",
				"kernel/src/data/multiboot.d",
				"kernel/src/data/text.d",
				"kernel/src/data/utf.d",
				"kernel/src/fs/iofs/package.d",
				"kernel/src/fs/iofs/stdionode.d",
				"kernel/src/fs/mountnode.d",
				"kernel/src/fs/node.d",
				"kernel/src/fs/nullfs.d",
				"kernel/src/fs/package.d",
				"kernel/src/fs/tarfs.d",
				"kernel/src/hw/cmos/cmos.d",
				"kernel/src/hw/pci/pci.d",
				"kernel/src/hw/ps2/kbset.d",
				"kernel/src/hw/ps2/keyboard.d",
				"kernel/src/invariant.d",
				"kernel/src/io/com.d",
				"kernel/src/io/consolemanager.d",
				"kernel/src/io/port.d",
				"kernel/src/io/log.d",
				"kernel/src/io/textmode.d",
				"kernel/src/memory/allocator/kheapallocator.d",
				"kernel/src/memory/allocator/package.d",
				"kernel/src/memory/vmm.d",
				"kernel/src/memory/ptr.d",
				"kernel/src/memory/frameallocator.d",
				"kernel/src/memory/kheap.d",
				"kernel/src/system/syscallhandler.d",
				"kernel/src/system/utils.d",
				"kernel/src/system/syscall.d",
				"kernel/src/task/mutex/schedulemutex.d",
				"kernel/src/task/mutex/spinlockmutex.d",
				"kernel/src/task/scheduler.d",
				"kernel/src/task/process.d",
				"kernel/src/util/trait.d",
				"kernel/src/object.d",
				"kernel/src/kmain.d"
			);

			auto aFiles = files!(
				"kernel/src/extra.S",
				"kernel/src/system/syscallhelper.S",
				"kernel/src/task/mutex/assembly.S",
				"kernel/src/task/task.S",
				"kernel/src/boot.S"
			);

			auto consoleFont = files!(
				"disk/data/font/terminus/ter-v16n.psf",
				"disk/data/font/terminus/ter-v16b.psf"
			);
			// dfmt on

			auto dCompiler = Processor.combine("cc/bin/powernex-dmd " ~ dCompilerArgsKernel);
			auto aCompiler = Processor.combine("cc/bin/x86_64-powernex-as " ~ aCompilerArgsKernel);
			auto linker = Processor.combine("cc/bin/x86_64-powernex-ld " ~ linkerArgsKernel);

			outputs["powernex"] = linker("disk/boot/powernex.krl", false, [dCompiler("dcode.o", false, dFiles, consoleFont),
					aCompiler("acode.o", false, aFiles)]);
		}
		registerProject(kernel);
	}

	{
		Project iso = new Project("PowerNexOS", SemVer(0, 0, 0));
		with (iso) {
			import std.algorithm : map;
			import std.array : array;

			auto loader = findDependency("PowerD");
			dependencies ~= loader;
			auto kernel = findDependency("PowerNex");
			dependencies ~= kernel;
			auto initrd = findDependency("PowerNexOS-InitRD");
			dependencies ~= initrd;

			// dfmt off
			Target[] bootFiles = [
				loader.outputs["powerd"],
				kernel.outputs["powernex"],
				initrd.outputs["initrd"]
			];
			// dfmt on

			auto createISO = Processor.combine("grub-mkrescue -d /usr/lib/grub/i386-pc -o $out$ $in$");

			auto grubCfg = cp("disk/boot/grub/grub.cfg", false, files!("disk/boot/grub/grub.cfg"));
			auto diskBoot = cp("disk/boot", false, bootFiles);

			auto diskDirectory = nothing("disk", false, null, [grubCfg, diskBoot]);
			outputs["iso"] = createISO("powernex.iso", false, [diskDirectory]);
		}
		registerProject(iso);
	}
}

int main(string[] args) {
	import std.stdio;

	setupProjects();

	auto os = findDependency("PowerNexOS");
	SysTime buildFileTime = DirEntry(args[0]).timeLastModified;
	//os.dotGraph();

	BuildInfo bi = os.gatherBuildInfo();
	normal("Needs to rebuild ", bi.targets.length, " target(s)\n");

	buildProject(bi);

	import std.process : executeShell;

	executeShell("ln -s " ~ os.outputs["iso"].output.path ~ " powernex.iso");
	return 0;
}
