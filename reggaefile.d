import reggae;
import utils.buildhelper;

import std.traits;
import std.file;
import std.algorithm;
import std.range;

//dfmt off
enum powerNexIsoName = "powernex.iso";
enum objDir = topLevelDirName(Target(powerNexIsoName));

enum CompileCommand : string {
	dc = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -fPIC -debug -c -g -Ikernel/src -I" ~ objDir ~ "/kernel/src -Jkernel/src -J" ~ objDir ~ "/kernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	dc_header = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -fPIC -debug -c -g -Ikernel/src -I" ~ objDir ~ "/kernel/src -Jkernel/src -J" ~ objDir ~ "/kernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -o- -Hf$out $in",
	ac = "cc/bin/x86_64-powernex-as --64 -o $out $in",
	ld = "cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T kernel/src/kernel.ld",
	iso = "grub-mkrescue -d /usr/lib/grub/i386-pc -o $out $in",
	ndc = "dmd -of$out -od" ~ objDir ~ "/utils/obj $in",
	copy = "cp -rf $in $out",
	ungzip = "gzip -d -c $in > $out",

	user_dc = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -debug -c -g -Iuserspace/librt/src -Iuserspace/libpowernex/src -I" ~ objDir ~ "/userspace/librt/src -I" ~ objDir ~ "/userspace/libpowernex/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	user_dc_e = "cc/bin/powernex-dmd -m64 -dip25 -de -color=on -debug -g -Iuserspace/librt/src -Iuserspace/libpowernex/src -I" ~ objDir ~ "/userspace/librt/src -I" ~ objDir ~ "/userspace/libpowernex/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
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

enum kernelDSources = mapKernelSources(
	"invariant.d",
	"object.d",
	"kmain.d",
	"acpi/rsdp.d",
	"bin/consolefont.d",
	"cpu/gdt.d",
	"cpu/idt.d",
	"cpu/msr.d",
	"cpu/tss.d",
	"cpu/pit.d",
	"data/address.d",
	"data/bitfield.d",
	"data/bmpimage.d",
	"data/color.d",
	"data/container.d",
	"data/elf.d",
	"data/font.d",
	"data/linkedlist.d",
	"data/linker.d",
	"data/multiboot.d",
	"data/parameters.d",
	"data/psf.d",
	"data/range.d",
	"data/register.d",
	"data/screen.d",
	"data/string_.d",
	"data/textbuffer.d",
	"data/utf.d",
	"data/util.d",
	"fs/node.d",
	"fs/nullfs.d",
	"fs/package.d",
	"hw/cmos/cmos.d",
	"hw/pci/pci.d",
	"hw/ps2/kbset.d",
	"hw/ps2/keyboard.d",
	"io/com.d",
	"io/port.d",
	"io/consolemanager.d",
	"io/log.d",
	"io/textmode.d",
	"io/fs/node.d",
	"io/fs/filenode.d",
	"io/fs/directorynode.d",
	"io/fs/package.d",
	"io/fs/softlinknode.d",
	"io/fs/hardlinknode.d",
	"io/fs/mountpointnode.d",
	"io/fs/nodepermission.d",
	"io/fs/fsroot.d",
	"io/fs/system/fsroot.d",
	"io/fs/system/versionnode.d",
	"io/fs/system/package.d",
	"io/fs/initrd/package.d",
	"io/fs/initrd/fsroot.d",
	"io/fs/initrd/filenode.d",
	"io/fs/io/package.d",
	"io/fs/io/boolnode.d",
	"io/fs/io/zeronode.d",
	"io/fs/io/fsroot.d",
	"io/fs/io/framebuffer/package.d",
	"io/fs/io/framebuffer/framebuffer.d",
	"io/fs/io/framebuffer/bgaframebuffer.d",
	"io/fs/io/console/console.d",
	"io/fs/io/console/package.d",
	"io/fs/io/console/serialconsole.d",
	"io/fs/io/console/virtualconsole.d",
	"io/fs/io/console/screen/package.d",
	"io/fs/io/console/screen/formattedchar.d",
	"io/fs/io/console/screen/virtualconsolescreen.d",
	"io/fs/io/console/screen/virtualconsolescreentextmode.d",
	"io/fs/io/console/screen/virtualconsolescreenframebuffer.d",
	"memory/allocator/heapallocator.d",
	"memory/allocator/package.d",
	"memory/allocator/staticallocator.d",
	"memory/frameallocator.d",
	"memory/heap.d",
	"memory/paging.d",
	"memory/ref_.d",
	"system/utils.d",
	"system/syscall.d",
	"system/syscallhandler.d",
	"task/process.d",
	"task/scheduler.d",
	"task/mutex/spinlockmutex.d",
	"task/mutex/schedulemutex.d"
);

enum kernelASources = mapKernelSources(
	"system/syscallhelper.S",
	"task/task.S",
	"task/mutex/assembly.S",
	"boot.S",
	"bootx64.S",
	"extra.S"
);

struct KernelTask {
static:
	enum kernel_aobj = Target("kernel/obj/acode.o", CompileCommand.ac, kernelASources);
	enum kernel_dobj = Target("kernel/obj/dcode.o", CompileCommand.dc, kernelDSources, [KernelDependency.consolefont]);
	enum kernel = Target("disk/boot/powernex.krl", CompileCommand.ld, [KernelTask.kernel_aobj, KernelTask.kernel_dobj]);
	enum map = Target("initrd/data/powernex.map", ToolCommand.generateSymbols, [KernelTask.kernel], [UtilsProgram.generatesymbols]);
}

struct UserspaceLibrary {
static:
	enum syscall_di = Target("userspace/syscall.di", CompileCommand.dc_header, [Target("kernel/src/system/syscall.d")]);
	enum syscall = Target("userspace/libpowernex/src/powernex/internal/syscall.di", ToolCommand.removeImports, [UserspaceLibrary.syscall_di]);

	enum librt = userspaceLibrary!("librt", [UserspaceLibrary.libpowernex], "invariant.d", "object.d");
	enum libpowernex = userspaceLibrary!("libpowernex", [],
		"powernex/data/address.d",
		"powernex/data/parameters.d",
		"powernex/data/string_.d",
		"powernex/data/util.d",
		"powernex/data/color.d",
		"powernex/data/bmpimage.d",
		"powernex/syscall.d"
	);
}

enum userPrograms = userspacePrograms!("init", "shell", "helloworld", "cat", "dlogo", "pattern");

enum initrdFiles = Target("initrd/", CompileCommand.copy, [Target("initrd/")], [
	Target("initrd/data/dlogo.bmp")
]);
enum initrd = Target("disk/boot/powernex.dsk", ToolCommand.makeInitrd, [initrdFiles], [
	UtilsProgram.makeinitrd,
	KernelTask.map,
	userPrograms
]);

enum isoFiles = Target("disk/", CompileCommand.copy, [Target("disk/")], [
	Target("disk/boot/grub/grub.cfg")
]);
enum powernexIso = Target(powerNexIsoName, CompileCommand.iso, [isoFiles], [KernelTask.kernel, initrd]);

mixin build!(powernexIso);
