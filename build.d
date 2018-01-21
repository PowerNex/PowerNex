#!/usr/bin/rdmd
module build;

import src.buildlib;

import std.algorithm;
import std.string;
import std.array;
import std.range;
import std.datetime : SysTime;
import std.file : DirEntry;

immutable {
	string ccPrefix = "build/cc/bin/";
	string dCompilerPath = ccPrefix ~ "powernex-dmd";
	string aCompilerPath = ccPrefix ~ "x86_64-powernex-as";
	string linkerPath = ccPrefix ~ "x86_64-powernex-ld";
}

shared static this() {
	import std.format : format;

	{
		import src.system.project : setupProject;

		setupProject();
	}

	auto nothing = Processor.combine("");
	auto cp = Processor.combine("cp --reflink=auto $in$ $out$");

	{
		Project initrd = new Project("PowerNexOS-InitRD", SemVer(0, 0, 0));
		with (initrd) {
			// dfmt off
			auto initrdFiles = files!("data/initrd/data/",
				"dlogo.bmp"
			);
			auto initrdDataDir = cp("initrd/data/", false, initrdFiles);
			auto initrdDir = nothing("initrd", false, null, [initrdDataDir]);
			// dfmt on

			auto makeInitrd = Processor.combine("tar -c --posix -f $out$ -C $in$ .");

			outputs["initrd"] = makeInitrd("powernex-initrd.dsk", false, [initrdDir]);
		}
		registerProject(initrd);
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

			auto grubCfg = cp("disk/boot/grub/grub.cfg", false, files!("", "data/disk/boot/grub/grub.cfg"));
			auto diskBoot = cp("disk/boot", false, bootFiles);

			auto diskDirectory = nothing("disk", false, null, [grubCfg, diskBoot]);
			outputs["iso"] = createISO("powernex.iso", false, [diskDirectory]);
		}
		registerProject(iso);
	}
}

int main(string[] args) {
	import std.stdio;

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
