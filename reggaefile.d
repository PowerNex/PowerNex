import reggae;
import std.traits;
import std.file;
import std.algorithm;
import std.range;

//dfmt off
template AllDFiles(string dir) {
	static if (dir == "kernel/src")
		enum files = "kernel/src/invariant.d kernel/src/object.d kernel/src/kmain.d kernel/src/acpi/rsdp.d kernel/src/bin/consolefont.d kernel/src/cpu/gdt.d kernel/src/cpu/idt.d kernel/src/cpu/msr.d kernel/src/cpu/tss.d kernel/src/cpu/pit.d kernel/src/data/address.d kernel/src/data/bitfield.d kernel/src/data/bmpimage.d kernel/src/data/color.d kernel/src/data/elf.d kernel/src/data/font.d kernel/src/data/linkedlist.d kernel/src/data/linker.d kernel/src/data/multiboot.d kernel/src/data/parameters.d kernel/src/data/psf.d kernel/src/data/register.d kernel/src/data/screen.d kernel/src/data/textbuffer.d kernel/src/data/utf.d kernel/src/data/util.d kernel/src/data/string_.d kernel/src/hw/cmos/cmos.d kernel/src/hw/pci/pci.d kernel/src/hw/ps2/kbset.d kernel/src/hw/ps2/keyboard.d kernel/src/io/com.d kernel/src/io/port.d kernel/src/io/consolemanager.d kernel/src/io/log.d kernel/src/io/textmode.d kernel/src/io/fs/node.d kernel/src/io/fs/filenode.d kernel/src/io/fs/directorynode.d kernel/src/io/fs/package.d kernel/src/io/fs/softlinknode.d kernel/src/io/fs/hardlinknode.d kernel/src/io/fs/mountpointnode.d kernel/src/io/fs/nodepermission.d kernel/src/io/fs/fsroot.d kernel/src/io/fs/system/fsroot.d kernel/src/io/fs/system/versionnode.d kernel/src/io/fs/system/package.d kernel/src/io/fs/initrd/package.d kernel/src/io/fs/initrd/fsroot.d kernel/src/io/fs/initrd/filenode.d kernel/src/io/fs/io/package.d kernel/src/io/fs/io/boolnode.d kernel/src/io/fs/io/zeronode.d kernel/src/io/fs/io/fsroot.d kernel/src/io/fs/io/framebuffer/package.d kernel/src/io/fs/io/framebuffer/framebuffer.d kernel/src/io/fs/io/framebuffer/bgaframebuffer.d kernel/src/io/fs/io/console/console.d kernel/src/io/fs/io/console/package.d kernel/src/io/fs/io/console/serialconsole.d kernel/src/io/fs/io/console/virtualconsole.d kernel/src/io/fs/io/console/screen/package.d kernel/src/io/fs/io/console/screen/formattedchar.d kernel/src/io/fs/io/console/screen/virtualconsolescreen.d kernel/src/io/fs/io/console/screen/virtualconsolescreentextmode.d kernel/src/io/fs/io/console/screen/virtualconsolescreenframebuffer.d kernel/src/memory/frameallocator.d kernel/src/memory/heap.d kernel/src/memory/paging.d kernel/src/system/utils.d kernel/src/system/syscall.d kernel/src/system/syscallhandler.d kernel/src/task/process.d kernel/src/task/scheduler.d kernel/src/task/mutex/spinlockmutex.d kernel/src/task/mutex/schedulemutex.d";
	else static if (dir == "userspace/librt/src")
		enum files = "userspace/librt/src/invariant.d userspace/librt/src/object.d";
	else static if (dir == "userspace/libpowernex/src")
		enum files = "userspace/libpowernex/src/powernex/data/address.d userspace/libpowernex/src/powernex/data/parameters.d userspace/libpowernex/src/powernex/data/string_.d userspace/libpowernex/src/powernex/data/util.d userspace/libpowernex/src/powernex/data/color.d userspace/libpowernex/src/powernex/data/bmpimage.d userspace/libpowernex/src/powernex/syscall.d";
	else static if (dir == "userspace/init/src")
		enum files = "userspace/init/src/app.d";
	else static if (dir == "userspace/shell/src")
		enum files = "userspace/shell/src/app.d";
	else static if (dir == "userspace/helloworld/src")
		enum files = "userspace/helloworld/src/app.d";
	else static if (dir == "userspace/cat/src")
		enum files = "userspace/cat/src/app.d";
	else static if (dir == "userspace/dlogo/src")
		enum files = "userspace/dlogo/src/app.d";
	else static if (dir == "userspace/pattern/src")
		enum files = "userspace/pattern/src/app.d";
	else
		static assert(0);

	enum AllDFiles = files.split(" ").map!Target.array;
}

template AllAFiles(string dir) {
	static if (dir == "kernel/src")
		enum files = "kernel/src/system/syscallhelper.S kernel/src/task/task.S kernel/src/task/mutex/assembly.S kernel/src/boot.S kernel/src/bootx64.S kernel/src/extra.S";
	else
		static assert(0);
	enum AllAFiles = files.split(" ").map!Target.array;
}

enum powerNexIsoName = "powernex.iso";
enum objDir = topLevelDirName(Target(powerNexIsoName));

enum CompileCommand : string {
	dc = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -fPIC -debug -c -g -Ikernel/src -I"~objDir~"/kernel/src -Jkernel/src -J"~objDir~"/kernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	dc_header = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -fPIC -debug -c -g -Ikernel/src -I"~objDir~"/kernel/src -Jkernel/src -J"~objDir~"/kernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -o- -Hf$out $in",
	ac = "cc/bin/x86_64-powernex-as --64 -o $out $in",
	ld = "cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T kernel/src/kernel.ld",
	iso = "grub-mkrescue -d /usr/lib/grub/i386-pc -o $out $in",
	ndc = "dmd -of$out -od"~objDir ~ "/utils/obj $in",
	copy = "cp -rf $in $out",
	ungzip = "gzip -d -c $in > $out",

	user_dc = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -debug -c -g -Iuserspace/librt/src -Iuserspace/libpowernex/src -I"~objDir~"/userspace/librt/src -I"~objDir~"/userspace/libpowernex/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	user_dc_e = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -debug -g -Iuserspace/librt/src -Iuserspace/libpowernex/src -I"~objDir~"/userspace/librt/src -I"~objDir~"/userspace/libpowernex/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	user_ac = "cc/bin/x86_64-powernex-as --64 -o $out $in",
	user_ar = "cc/bin/x86_64-powernex-ar rcs $out $in",
	user_ld = "cc/bin/x86_64-powernex-ld -o $out $in"
}

enum ToolCommand : string {
	generateSymbols = objDir ~ "/utils/generatesymbols $in $out",
	makeInitrd = objDir ~ "/utils/makeinitrd $in $out",
	removeImports = "sed -e 's/^import .*//g' -e 's/enum/import powernex.data.address;\\nenum/' -e 's/module system.syscall;/module powernex.internal.syscall;/' $in > $out",
}

struct UtilsProgram {
static:
	enum generatesymbols = Target("utils/generatesymbols", CompileCommand.ndc, [Target("utils/generatesymbols.d")]);
	enum makeinitrd = Target("utils/makeinitrd", CompileCommand.ndc, [Target("utils/makeinitrd.d")]);
}

struct KernelDependency {
static:
	enum consolefontgz = Target("kernel/src/bin/consoleFont.psf.gz", CompileCommand.copy, [Target("/usr/share/kbd/consolefonts/lat9w-16.psfu.gz")]);
	enum consolefont = Target("kernel/src/bin/consoleFont.psf", CompileCommand.ungzip, [KernelDependency.consolefontgz]);
}

struct KernelTask {
static:
	enum kernel_aobj = Target("kernel/obj/acode.o", CompileCommand.ac, AllAFiles!"kernel/src");
	enum kernel_dobj = Target("kernel/obj/dcode.o", CompileCommand.dc, AllDFiles!"kernel/src", [KernelDependency.consolefont]);
	enum kernel = Target("disk/boot/powernex.krl", CompileCommand.ld, [KernelTask.kernel_aobj, KernelTask.kernel_dobj]);
	enum map = Target("initrd/data/powernex.map", ToolCommand.generateSymbols, [KernelTask.kernel], [UtilsProgram.generatesymbols]);
}

struct UserspaceLibrary {
static:
	enum syscall_di = Target("userspace/syscall.di", CompileCommand.dc_header, [Target("kernel/src/system/syscall.d")]);
	enum syscall = Target("userspace/libpowernex/src/powernex/internal/syscall.di", ToolCommand.removeImports, [UserspaceLibrary.syscall_di]);

	enum librt_obj = Target("userspace/librt/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/librt/src", [UserspaceLibrary.syscall]);
	enum librt = Target("userspace/lib/librt.a", CompileCommand.user_ar, [UserspaceLibrary.librt_obj], [UserspaceLibrary.libpowernex]);

	enum libpowernex_obj = Target("userspace/libpowernex/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/libpowernex/src", [UserspaceLibrary.syscall]);
	enum libpowernex = Target("userspace/lib/libpowernex.a", CompileCommand.user_ar, [UserspaceLibrary.libpowernex_obj]);
}

struct UserspaceProgram {
static:
	enum init_obj = Target("userspace/init/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/init/src", [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
	enum init = Target("initrd/bin/init", CompileCommand.user_ld, [UserspaceProgram.init_obj, UserspaceLibrary.librt, UserspaceLibrary.libpowernex], [UserspaceLibrary.libpowernex]);

	enum shell_obj = Target("userspace/shell/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/shell/src", [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
	enum shell = Target("initrd/bin/shell", CompileCommand.user_ld, [UserspaceProgram.shell_obj, UserspaceLibrary.librt, UserspaceLibrary.libpowernex], [UserspaceLibrary.libpowernex]);

	enum helloworld_obj = Target("userspace/helloworld/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/helloworld/src", [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
	enum helloworld = Target("initrd/bin/helloworld", CompileCommand.user_ld, [UserspaceProgram.helloworld_obj, UserspaceLibrary.librt, UserspaceLibrary.libpowernex], [UserspaceLibrary.libpowernex]);

	enum cat_obj = Target("userspace/cat/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/cat/src", [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
	enum cat = Target("initrd/bin/cat", CompileCommand.user_ld, [UserspaceProgram.cat_obj, UserspaceLibrary.librt, UserspaceLibrary.libpowernex], [UserspaceLibrary.libpowernex]);

	enum dlogo_obj = Target("userspace/dlogo/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/dlogo/src", [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
	enum dlogo = Target("initrd/bin/dlogo", CompileCommand.user_ld, [UserspaceProgram.dlogo_obj, UserspaceLibrary.librt, UserspaceLibrary.libpowernex], [UserspaceLibrary.libpowernex]);

	enum pattern_obj = Target("userspace/pattern/obj/dcode.o", CompileCommand.user_dc, AllDFiles!"userspace/pattern/src", [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
	enum pattern = Target("initrd/bin/pattern", CompileCommand.user_ld, [UserspaceProgram.pattern_obj, UserspaceLibrary.librt, UserspaceLibrary.libpowernex], [UserspaceLibrary.libpowernex]);
}

enum initrdFiles = Target("initrd/", CompileCommand.copy, [Target("initrd/")], [
	Target("initrd/data/dlogo.bmp")
]);
enum initrd = Target("disk/boot/powernex.dsk", ToolCommand.makeInitrd, [initrdFiles], [
	UtilsProgram.makeinitrd,
	KernelTask.map,
	UserspaceProgram.init,
	UserspaceProgram.shell,
	UserspaceProgram.helloworld,
	UserspaceProgram.cat,
	UserspaceProgram.dlogo,
	UserspaceProgram.pattern
]);

enum isoFiles = Target("disk/", CompileCommand.copy, [Target("disk/")], [
	Target("disk/boot/grub/grub.cfg")
]);
enum powernexIso = Target(powerNexIsoName, CompileCommand.iso, [isoFiles], [KernelTask.kernel, initrd]);

mixin build!(powernexIso);
