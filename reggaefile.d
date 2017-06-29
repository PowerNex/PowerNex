import reggae;

import std.traits;
import std.file;
import std.algorithm;
import std.range;

enum powerNexIsoName = "powernex.iso";
enum objDir = topLevelDirName(Target(powerNexIsoName));

//dfmt off
enum CompileCommand : string {
	nothing = "true $in",
	iso = "grub-mkrescue -d /usr/lib/grub/i386-pc -o $out $in",
	ndc = "dmd -of$out -od" ~ objDir ~ "/utils/obj $in",
	copy = "cp -r $in $out",
	ungzip = "gzip -d -c $in > $out",

	loader_ac = "cc/bin/x86_64-powernex-as --64 -o $out $in",
	loader_dc = "cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -debug -c -g -version=PowerD -Iloader/src -I" ~ objDir ~ "/loader/src -Jloader/src -J" ~ objDir ~ "/loader/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/loader -X -Xfdocs-loader.json -of$out $in",
	loader_dc_header = "cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -IIloader/src -I" ~ objDir ~ "/Iloader/src -JIloader/src -J" ~ objDir ~ "/Iloader/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -o- -Hf$out $in",
	loader_ld = "cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T loader/src/loader.ld -nostdlib --gc-sections",

	//TODO: change back -dw to -de, re-add -vgc?
	kernel_dc = "cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -Ikernel/src -I" ~ objDir ~ "/kernel/src -Jkernel/src -J" ~ objDir ~ "/kernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/kernel -X -Xfdocs-kernel.json -of$out $in",
	kernel_dc_header = "cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -Ikernel/src -I" ~ objDir ~ "/kernel/src -Jkernel/src -J" ~ objDir ~ "/kernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -o- -Hf$out $in",
	kernel_ac = "cc/bin/x86_64-powernex-as --divide --64 -o $out $in",
	kernel_ld = "cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T kernel/src/kernel.ld",

	user_dc = "cc/bin/powernex-dmd -m64 -dip25 -dip1000 -de -color=on -debug -c -g -Iuserspace/librt/src -Iuserspace/libpowernex/src -I" ~ objDir ~ "/userspace/librt/src -I" ~ objDir ~ "/userspace/libpowernex/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	user_dc_e = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -debug -g -Iuserspace/librt/src -Iuserspace/libpowernex/src -I" ~ objDir ~ "/userspace/librt/src -I" ~ objDir ~ "/userspace/libpowernex/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	user_ac = "cc/bin/x86_64-powernex-as --divide --64 -o $out $in",
	user_ar = "cc/bin/x86_64-powernex-ar rcs $out $in",
	user_ld = "cc/bin/x86_64-powernex-ld -o $out $in"
}

enum ToolCommand : string {
	generateSymbols = objDir ~ "/utils/generatesymbols $in $out",
	makeInitrdOld = objDir ~ "/utils/makeinitrdold $in $out",
	makeInitrd = "tar -c --posix -f $out -C $in .",
	removeImports = "sed -e 's/^import .*//g' -e 's/enum/import powernex.data.address;\\nenum/' -e 's/module system.syscall;/module powernex.internal.syscall;/' $in > $out",
	ddox = "dub run ddox -- generate-html $in $out"
}
//dfmt on

Target[] mapSources(string rootFolder, string glob = "*.d") {
	import std.file : dirEntries, SpanMode;
	import std.algorithm : filter;

	Target[] srcs;
	foreach (f; dirEntries(rootFolder, glob, SpanMode.breadth).filter!(x => !x.isDir))
		srcs ~= Target(f);

	return srcs;
}

class UtilsPrograms {
	Target generatesymbols;
	Target makeinitrdold;

	this() {
		generatesymbols = Target("utils/generatesymbols", CompileCommand.ndc, [Target("utils/generatesymbols.d")]);
		makeinitrdold = Target("utils/makeinitrdold", CompileCommand.ndc, [Target("utils/makeinitrd.d")]);
	}
}

class Loader {
	//Target apiBaseDi;
	Target loaderAObj;
	Target loaderDObj;
	Target loader;

	this() {
		//apiBaseDi = Target("kernel/base.di", CompileCommand.loader_dc_header, [Target("loader/src/api/base.d")]);
		loaderAObj = Target("loader/obj/acode.o", CompileCommand.loader_ac, mapSources("loader/", "*.S"));
		loaderDObj = Target("loader/obj/dcode.o", CompileCommand.loader_dc, mapSources("loader/"));
		loader = Target("disk/boot/powerd.ldr", CompileCommand.loader_ld, [loaderAObj, loaderDObj]);
	}
}

class KernelDependencies {
	Target consolefontgz;
	Target consolefont;

	this() {
		consolefontgz = Target("kernel/src/bin/consoleFont.psf.gz", CompileCommand.copy,
				[Target("/usr/share/kbd/consolefonts/lat9w-16.psfu.gz")]);
		consolefont = Target("kernel/src/bin/consoleFont.psf", CompileCommand.ungzip, [consolefontgz]);
	}
}

class Kernel {
	Target kernelAObj;
	Target kernelDObj;
	Target kernel;
	Target map;

	this() {
		kernelAObj = Target("kernel/obj/acode.o", CompileCommand.kernel_ac, mapSources("kernel/", "*.S"));
		kernelDObj = Target("kernel/obj/dcode.o", CompileCommand.kernel_dc, mapSources("kernel/"), [kernelDependencies.consolefont]);
		kernel = Target("disk/boot/powernex.krl", CompileCommand.kernel_ld, [kernelAObj, kernelDObj]);
		map = Target("disk/boot/powernex.map", ToolCommand.generateSymbols, [kernel], [utilsPrograms.generatesymbols]);
	}
}

class UserspaceLibraries {
	Target syscallDi;
	Target syscall;
	Target libpowernexObj;
	Target libpowernex;
	Target librtObj;
	Target librt;

	this() {
		syscallDi = Target("userspace/syscall.di", CompileCommand.kernel_dc_header, [Target("kernel/src/system/syscall.d")]);
		syscall = Target("userspace/libpowernex/src/powernex/internal/syscall.di", ToolCommand.removeImports, [syscallDi]);

		libpowernexObj = Target("userspace/libpowernex/obj/dcode.o", CompileCommand.user_dc, mapSources("userspace/libpowernex/"), [syscall]);
		libpowernex = Target("userspace/lib/libpowernex", CompileCommand.user_ar, [libpowernexObj], []);

		librtObj = Target("userspace/librt/obj/dcode.o", CompileCommand.user_dc, mapSources("userspace/librt/"), [syscall]);
		librt = Target("userspace/lib/librt", CompileCommand.user_ar, [librtObj], [libpowernex]);
	}
}

class UserspacePrograms {
	Target initObj;
	Target init_;
	Target loginObj;
	Target login;
	Target shellObj;
	Target shell;
	Target helloworldObj;
	Target helloworld;
	Target catObj;
	Target cat;

	this() {
		initObj = Target("userspace/init/obj/dcode.o", CompileCommand.user_dc, mapSources("userspace/init/"),
				[userspaceLibraries.librt, userspaceLibraries.libpowernex]);
		init_ = Target("initrd/bin/init", CompileCommand.user_ld, [initObj, userspaceLibraries.librt,
				userspaceLibraries.libpowernex], [userspaceLibraries.libpowernex]);

		loginObj = Target("userspace/login/obj/dcode.o", CompileCommand.user_dc, mapSources("userspace/login/"),
				[userspaceLibraries.librt, userspaceLibraries.libpowernex]);
		login = Target("initrd/bin/login", CompileCommand.user_ld, [loginObj, userspaceLibraries.librt,
				userspaceLibraries.libpowernex], [userspaceLibraries.libpowernex]);

		shellObj = Target("userspace/shell/obj/dcode.o", CompileCommand.user_dc, mapSources("userspace/shell/"),
				[userspaceLibraries.librt, userspaceLibraries.libpowernex]);
		shell = Target("initrd/bin/shell", CompileCommand.user_ld, [shellObj, userspaceLibraries.librt,
				userspaceLibraries.libpowernex], [userspaceLibraries.libpowernex]);

		helloworldObj = Target("userspace/helloworld/obj/dcode.o", CompileCommand.user_dc,
				mapSources("userspace/helloworld/"), [userspaceLibraries.librt, userspaceLibraries.libpowernex]);
		helloworld = Target("initrd/bin/helloworld", CompileCommand.user_ld, [helloworldObj, userspaceLibraries.librt,
				userspaceLibraries.libpowernex], [userspaceLibraries.libpowernex]);

		catObj = Target("userspace/cat/obj/dcode.o", CompileCommand.user_dc, mapSources("userspace/cat/"),
				[userspaceLibraries.librt, userspaceLibraries.libpowernex]);
		cat = Target("initrd/bin/cat", CompileCommand.user_ld, [catObj, userspaceLibraries.librt,
				userspaceLibraries.libpowernex], [userspaceLibraries.libpowernex]);
	}
}

UtilsPrograms utilsPrograms;
Loader loader;
KernelDependencies kernelDependencies;
Kernel kernel;
UserspaceLibraries userspaceLibraries;
UserspacePrograms userspacePrograms;

Build myBuild() {
	utilsPrograms = new UtilsPrograms();
	loader = new Loader();
	kernelDependencies = new KernelDependencies();
	kernel = new Kernel();
	userspaceLibraries = new UserspaceLibraries();
	userspacePrograms = new UserspacePrograms();

	auto dlogo = Target("initrd/data/dlogo.bmp", CompileCommand.copy, [Target("initrd/data/dlogo.bmp")]);
	auto initrdFiles = Target.phony("initrd/", CompileCommand.nothing, [dlogo]);

	auto initrd = Target("disk/boot/powernex-initrd.dsk", ToolCommand.makeInitrd, [initrdFiles], [initrdFiles,
			userspacePrograms.init_, userspacePrograms.login, userspacePrograms.shell, userspacePrograms.helloworld, userspacePrograms.cat]);

	auto grubCfg = Target("disk/boot/grub/grub.cfg", CompileCommand.copy, [Target("disk/boot/grub/grub.cfg")]);
	auto isoFiles = Target.phony("disk/", CompileCommand.nothing, [grubCfg, loader.loader, kernel.kernel, /* initrdOld,*/ initrd, kernel.map]);
	auto powernexIso = Target(powerNexIsoName, CompileCommand.iso, [isoFiles]);

	return Build(powernexIso);
}

void empty(in string[] inputs, in string[] outputs) {

}
