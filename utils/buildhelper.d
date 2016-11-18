module utils.buildhelper;

import reggaefile;

import reggae;

template Tuple(T...) {
	enum Tuple = T;
}

Target[] mapSources(string rootFolder, Sources...)(string name, Sources sources) {
	Target[] srcs = [];
	string prefix = rootFolder ~ name;
	foreach (s; sources)
		srcs ~= Target(prefix ~ "/src/" ~ s);
	return srcs;
}

Target[] mapKernelSources(Sources...)(Sources sources) {
	return mapSources!("kernel/")("", sources);
}

Target[] mapUserspaceSources(Sources...)(string name, Sources sources) {
	return mapSources!("userspace/")(name, "app.d", sources);
}

Target[] mapUserspaceLibSources(Sources...)(string name, Sources sources) {
	return mapSources!("userspace/")(name, sources);
}

template userspaceLibrary(string name, Target[] dependencies, Sources...) {
	enum obj = Target("userspace/" ~ name ~ "/obj/dcode.o", CompileCommand.user_dc, mapUserspaceLibSources(name, Sources),
				[UserspaceLibrary.syscall]);
	enum userspaceLibrary = Target("userspace/lib/" ~ name, CompileCommand.user_ar, [obj], dependencies);
}

template userspaceProgram(string name, Sources...) {
	enum obj = Target("userspace/" ~ name ~ "/obj/dcode.o", CompileCommand.user_dc, mapUserspaceSources(name, Sources),
				[UserspaceLibrary.librt, UserspaceLibrary.libpowernex]);
	enum userspaceProgram = Target("initrd/bin/" ~ name, CompileCommand.user_ld, [obj, UserspaceLibrary.librt,
				UserspaceLibrary.libpowernex], [UserspaceLibrary.libpowernex]);
}

template userspacePrograms(string program, Rest...) {
	static if (Rest.length)
		enum userspacePrograms = Tuple!(userspaceProgram!program, userspacePrograms!Rest);
	else
		enum userspacePrograms = Tuple!(userspaceProgram!program);
}
