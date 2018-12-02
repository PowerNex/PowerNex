module src.binaries.projects;

void setupProject() {
	initInit();
}

private:
import build;
import src.buildlib;

immutable {
	string dCompilerArgs = " -m64 -dip25 -dip1000 -dip1008 -fPIC -betterC -dw -color=on -debug -c -g -of$out$ $in$ -defaultlib=build/objs/DRuntime/libdruntime.a -debuglib=build/objs/DRuntime/libdruntime.a -Isrc/libraries/druntime";
	string linkerArgs = " -o $out$ $in$ -nostdlib --gc-sections";
	string archiveArgs = " rcs $out$ $in$";
}

void initInit() {
	Project init = new Project("Init", SemVer(0, 1, 337));
	with (init) {
		auto druntime = findDependency("DRuntime");
		dependencies ~= druntime;
		// dfmt off
		auto dFiles = files!("src/binaries/init/",
			"app.d"
		);
		// dfmt on

		auto dCompiler = Processor.combine(dCompilerPath ~ dCompilerArgs ~ " -version=Target_" ~ name);
		auto linker = Processor.combine(linkerPath ~ linkerArgs);

		outputs["init"] = linker("init", false, [dCompiler("dcode.o", false, dFiles), druntime.outputs["libdruntime"]]);
	}
	registerProject(init);
}
