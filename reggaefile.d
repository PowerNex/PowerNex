import reggae;
import std.traits;
import std.file;
import std.algorithm;
import std.range;

//enum AllFiles(string dir, string ext) = () => dirEntries(dir, SpanMode.depth).map!(f => f.name).filter!(f => f.endsWith(ext)).map!(f => Target(f)).array;
//enum AllDFiles(string dir) = AllFiles!(dir, ".d");

template AllDFiles(string dir) {
	static if (dir == "Kernel/src")
		enum files = "Kernel/src/CPU/TSS.d Kernel/src/CPU/GDT.d Kernel/src/CPU/IDT.d Kernel/src/CPU/MSR.d Kernel/src/CPU/PIT.d Kernel/src/Data/BitField.d Kernel/src/Data/Linker.d Kernel/src/Data/Screen.d Kernel/src/Data/Parameters.d Kernel/src/Data/Address.d Kernel/src/Data/BMPImage.d Kernel/src/Data/LinkedList.d Kernel/src/Data/Register.d Kernel/src/Data/String.d Kernel/src/Data/Util.d Kernel/src/Data/Color.d Kernel/src/Data/ELF.d Kernel/src/Data/Multiboot.d Kernel/src/Data/TextBuffer.d Kernel/src/Data/UTF.d Kernel/src/Data/Font.d Kernel/src/Data/PSF.d Kernel/src/Memory/FrameAllocator.d Kernel/src/Memory/Paging.d Kernel/src/Memory/Heap.d Kernel/src/IO/FS/package.d Kernel/src/IO/FS/Node.d Kernel/src/IO/FS/NodePermission.d Kernel/src/IO/FS/Initrd/package.d Kernel/src/IO/FS/Initrd/FSRoot.d Kernel/src/IO/FS/Initrd/FileNode.d Kernel/src/IO/FS/System/package.d Kernel/src/IO/FS/System/FSRoot.d Kernel/src/IO/FS/System/VersionNode.d Kernel/src/IO/FS/HardLinkNode.d Kernel/src/IO/FS/SoftLinkNode.d Kernel/src/IO/FS/DirectoryNode.d Kernel/src/IO/FS/FSRoot.d Kernel/src/IO/FS/FileNode.d Kernel/src/IO/FS/IO/BoolNode.d Kernel/src/IO/FS/IO/Console/Console.d Kernel/src/IO/FS/IO/Console/Screen/FormattedChar.d Kernel/src/IO/FS/IO/Console/Screen/VirtualConsoleScreen.d Kernel/src/IO/FS/IO/Console/Screen/VirtualConsoleScreenFramebuffer.d Kernel/src/IO/FS/IO/Console/Screen/VirtualConsoleScreenTextMode.d Kernel/src/IO/FS/IO/Console/Screen/package.d Kernel/src/IO/FS/IO/Console/SerialConsole.d Kernel/src/IO/FS/IO/Console/VirtualConsole.d Kernel/src/IO/FS/IO/Console/package.d Kernel/src/IO/FS/IO/Framebuffer/BGAFramebuffer.d Kernel/src/IO/FS/IO/Framebuffer/package.d Kernel/src/IO/FS/IO/Framebuffer/Framebuffer.d Kernel/src/IO/FS/IO/ZeroNode.d Kernel/src/IO/FS/IO/package.d Kernel/src/IO/FS/IO/FSRoot.d Kernel/src/IO/FS/MountPointNode.d Kernel/src/IO/Port.d Kernel/src/IO/TextMode.d Kernel/src/IO/COM.d Kernel/src/IO/Keyboard.d Kernel/src/IO/Log.d Kernel/src/IO/ConsoleManager.d Kernel/src/invariant.d Kernel/src/HW/PS2/KBSet.d Kernel/src/HW/PS2/Keyboard.d Kernel/src/HW/PCI/PCI.d Kernel/src/HW/CMOS/CMOS.d Kernel/src/Task/Mutex/ScheduleMutex.d Kernel/src/Task/Mutex/SpinLockMutex.d Kernel/src/Task/Process.d Kernel/src/Task/Scheduler.d Kernel/src/Bin/ConsoleFont.d Kernel/src/ACPI/RSDP.d Kernel/src/System/SyscallHandler.d Kernel/src/System/Utils.d Kernel/src/System/Syscall.d Kernel/src/object.d Kernel/src/KMain.d";
	else static if (dir == "Userspace/libRT/src")
		enum files = "Userspace/libRT/src/invariant.d Userspace/libRT/src/object.d";
	else static if (dir == "Userspace/libPowerNex/src")
		enum files = "Userspace/libPowerNex/src/PowerNex/Data/Address.d Userspace/libPowerNex/src/PowerNex/Data/Parameters.d Userspace/libPowerNex/src/PowerNex/Data/String.d Userspace/libPowerNex/src/PowerNex/Data/Util.d Userspace/libPowerNex/src/PowerNex/Data/Color.d Userspace/libPowerNex/src/PowerNex/Data/BMPImage.d Userspace/libPowerNex/src/PowerNex/Syscall.d";
	else static if (dir == "Userspace/Init/src")
		enum files = "Userspace/Init/src/app.d";
	else static if (dir == "Userspace/Shell/src")
		enum files = "Userspace/Shell/src/app.d";
	else static if (dir == "Userspace/HelloWorld/src")
		enum files = "Userspace/HelloWorld/src/app.d";
	else static if (dir == "Userspace/Cat/src")
		enum files = "Userspace/Cat/src/app.d";
	else static if (dir == "Userspace/DLogo/src")
		enum files = "Userspace/DLogo/src/app.d";
	else
		static assert(0);

	enum AllDFiles = files.split(" ").map!Target.array;
}

template AllAFiles(string dir) {
	static if (dir == "Kernel/src")
		enum files = "Kernel/src/BootX64.S Kernel/src/Task/Mutex/Assembly.S Kernel/src/Task/Task.S Kernel/src/System/SyscallHelper.S Kernel/src/Boot.S Kernel/src/Extra.S";
	else
		static assert(0);
	enum AllAFiles = files.split(" ").map!Target.array;
}

enum CompileCommand : string {
	dc = "cc/bin/powernex-dmd -m64 -fPIC -debug -c -g -IKernel/src -JKernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	dc_header = "cc/bin/powernex-dmd -m64 -fPIC -debug -c -g -IKernel/src -JKernel/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -o- -Hf$out $in",
	ac = "cc/bin/x86_64-powernex-as --64 -o $out $in",
	ld = "cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T Kernel/src/Kernel.ld",
	iso = "grub-mkrescue -d /usr/lib/grub/i386-pc -o $out $in",
	ndc = "dmd -of$out -odUtils/obj $in",
	copy = "cp -f $in $out",
	ungzip = "gzip -d -c $in > $out",
	GenerateSymbols = "Utils/GenerateSymbols $in $out",
	MakeInitrd = "Utils/MakeInitrd $in $out",

	RemoveImports = "sed -e 's/^import .*//g' -e 's/enum/import PowerNex.Data.Address;\\nenum/' $in > $out",

	user_dc = "cc/bin/powernex-dmd -m64 -debug -c -g -IUserspace/libRT/src -IUserspace/libPowerNex/src -defaultlib= -debuglib= -version=bare_metal -debug=allocations -of$out $in",
	user_ac = "cc/bin/x86_64-powernex-as --64 -o $out $in",
	user_ar = "cc/bin/x86_64-powernex-ar rcs $out $in",
	user_ld = "cc/bin/x86_64-powernex-ld -o $out $in Userspace/lib/libRT.a Userspace/lib/libPowerNex.a"
}

struct UtilsProgram {
static:
	enum generatesymbols = Target("Utils/GenerateSymbols", CompileCommand.ndc, [Target("Utils/GenerateSymbols.d")]);
	enum makeinitrd = Target("Utils/MakeInitrd", CompileCommand.ndc, [Target("Utils/MakeInitrd.d")]);
}

struct KernelDependency {
static:
	enum consolefontgz = Target("Kernel/src/Bin/ConsoleFont.psf.gz", CompileCommand.copy, [Target("/usr/share/kbd/consolefonts/lat9w-16.psfu.gz")]);
	enum consolefont = Target("Kernel/src/Bin/ConsoleFont.psf", CompileCommand.ungzip, [KernelDependency.consolefontgz]);
}

struct KernelTask {
static:
	//enum kernel_boot_obj = Target("Kernel/obj/asm/Boot.o", CompileCommand.ac, [Target("Kernel/src/Boot.S")]);
	//enum kernel_bootx64_obj = Target("Kernel/obj/asm/BootX64.o", CompileCommand.ac, [Target("Kernel/src/BootX64.S")]);
	enum kernel_aobj = Target("Kernel/obj/ACode.o", CompileCommand.ac, AllAFiles!"Kernel/src");
	enum kernel_dobj = Target("Kernel/obj/DCode.o", CompileCommand.dc, AllDFiles!"Kernel/src", [KernelDependency.consolefont]);
	enum kernel = Target("Disk/boot/PowerNex.krl", CompileCommand.ld, [KernelTask.kernel_aobj, KernelTask.kernel_dobj]);
	enum map = Target("Initrd/Data/PowerNex.map", CompileCommand.GenerateSymbols, [KernelTask.kernel], [UtilsProgram.generatesymbols]);
}

struct UserspaceLibrary {
static:
	enum syscall_di = Target("Userspace/Syscall.di", CompileCommand.dc_header, [Target("Kernel/src/System/Syscall.d")]);
	enum syscall = Target("Userspace/libPowerNex/src/PowerNex/Internal/Syscall.di", CompileCommand.RemoveImports, [syscall_di]);

	enum librt_obj = Target("Userspace/libRT/obj/DCode.o", CompileCommand.user_dc, AllDFiles!"Userspace/libRT/src");
	enum librt = Target("Userspace/lib/libRT.a", CompileCommand.user_ar, [librt_obj]);

	enum libpowernex_obj = Target("Userspace/libPowerNex/obj/DCode.o", CompileCommand.user_dc, AllDFiles!"Userspace/libPowerNex/src");
	enum libpowernex = Target("Userspace/lib/libPowerNex.a", CompileCommand.user_ar, [libpowernex_obj], [UserspaceLibrary.syscall]);
}

struct UserspaceProgram {
static:
	enum init_obj = Target("Userspace/Init/obj/DCode.o", CompileCommand.user_dc, AllDFiles!"Userspace/Init/src");
	enum init = Target("Initrd/Binary/Init", CompileCommand.user_ld, [UserspaceProgram.init_obj], [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);

	enum shell_obj = Target("Userspace/Shell/obj/DCode.o", CompileCommand.user_dc, AllDFiles!"Userspace/Shell/src");
	enum shell = Target("Initrd/Binary/Shell", CompileCommand.user_ld, [UserspaceProgram.shell_obj], [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);

	enum helloworld_obj = Target("Userspace/HelloWorld/obj/DCode.o", CompileCommand.user_dc, AllDFiles!"Userspace/HelloWorld/src");
	enum helloworld = Target("Initrd/Binary/HelloWorld", CompileCommand.user_ld, [UserspaceProgram.helloworld_obj], [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);

	enum cat_obj = Target("Userspace/Cat/obj/DCode.o", CompileCommand.user_dc, AllDFiles!"Userspace/Cat/src");
	enum cat = Target("Initrd/Binary/Cat", CompileCommand.user_ld, [UserspaceProgram.cat_obj], [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);

	enum dlogo_obj = Target("Userspace/DLogo/obj/DCode.o", CompileCommand.user_dc, AllDFiles!"Userspace/DLogo/src");
	enum dlogo = Target("Initrd/Binary/DLogo", CompileCommand.user_ld, [UserspaceProgram.dlogo_obj], [UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
}

enum initrd = Target("Disk/boot/PowerNex.dsk", CompileCommand.MakeInitrd, [Target("Initrd")], [UtilsProgram.makeinitrd, KernelTask.map,
	UserspaceProgram.init_obj,
	UserspaceProgram.init,
	UserspaceProgram.shell_obj,
	UserspaceProgram.shell,
	UserspaceProgram.helloworld_obj,
	UserspaceProgram.helloworld,
	UserspaceProgram.cat_obj,
	UserspaceProgram.cat,
	UserspaceProgram.dlogo_obj,
	UserspaceProgram.dlogo]);
enum iso = Target("PowerNex.iso", CompileCommand.iso, [Target("Disk"), Target("$builddir/Disk")], [KernelTask.kernel, initrd]);

mixin build!(iso);
