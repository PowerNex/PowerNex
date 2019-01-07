module src.libraries.projects;

void setupProject() {
	initDRuntime();
	initGFX();
}

private:
import build;
import src.buildlib;

immutable {
	string dCompilerArgs = " -m64 -dip25 -dip1000 -dip1008 -fPIC -betterC -dw -color=on -debug -c -g -of$out$ $in$ -version=bare_metal -debug=allocations -defaultlib=build/objs/DRuntime/libdruntime.a -debuglib=build/objs/DRuntime/libdruntime.a -Isrc/libraries/druntime";
	string linkerArgs = " -o $out$ $in$ -nostdlib --gc-sections";
	string archiveArgs = " rcs $out$ $in$";
}

void initDRuntime() {
	Project druntime = new Project("DRuntime", SemVer(0, 1, 337));
	with (druntime) {
		// dfmt off
		auto dFiles = files!("src/libraries/druntime/",
			"core/sys/powernex/io.d",
			"rt/memory.d",
			"std/stdio.d",
			"std/text.d",
			"std/traits.d",
			"object.d",
			"invariant.d"
		);
		// dfmt on

		auto dCompiler = Processor.combine(dCompilerPath ~ dCompilerArgs ~ " -version=Target_" ~ name ~ " -defaultlib= -debuglib=");
		auto archive = Processor.combine(archivePath ~ archiveArgs);

		outputs["libdruntime"] = archive("libdruntime.a", false, [dCompiler("dcode.o", false, dFiles)]);
	}
	registerProject(druntime);
}

void initGFX() {
	Project gfx = new Project("GFX", SemVer(0, 1, 337));
	with (gfx) {
		auto druntime = findDependency("DRuntime");
		dependencies ~= druntime;
		// dfmt off
		auto dFiles = files!("src/libraries/gfx/",
			"powernex/gfx/ppm.d",
		);
		// dfmt on

		auto dCompiler = Processor.combine(dCompilerPath ~ dCompilerArgs ~ " -version=Target_" ~ name ~ " -defaultlib= -debuglib=");
		auto archive = Processor.combine(archivePath ~ archiveArgs);

		outputs["libgfx"] = archive("libgfx.a", false, [dCompiler("dcode.o", false, dFiles)], [druntime.outputs["libdruntime"]]);
	}
	registerProject(gfx);
}
