#!/usr/bin/rdmd
import std.stdio;
import std.variant;

// dfmt off
void normal(Args...)(Args args)  { write("\x1b[39;1m", args, "\x1b[0m"); }
void good(Args...)(Args args)    { write("\x1b[32;1m", args, "\x1b[0m"); }
void warning(Args...)(Args args) { stderr.write("\x1b[31;1m", args, "\x1b[0m"); }
void error(Args...)(Args args)   { stderr.write("\x1b[37;41;1m", args, "\x1b[0m"); }
// dfmt on

void main() {
	//auto nativeDC = processor(["dmd -of$out -od" ~ objDir ~ "/utils/obj $in"]);

	Project loader = project("powerd.ldr", null, (Project this_) {
		auto dc = processor(
			"cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -color=on -debug -betterC -c -g -version=PowerD -Iloader/src -I" ~ this_.objDir ~ " -Jloader/src -J"
			~ this_.objDir
			~ " -Jdisk/ -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/loader -X -Xfdocs-loader.json -of$out $in");
		auto ac = processor("cc/bin/x86_64-powernex-as --64 -o $out $in");
		auto ld = processor("cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T loader/src/loader.ld -nostdlib");

		auto consoleFont = target(this_, "disk/data/font/terminus/ter-v16n.psf");
		auto consoleFontBold = target(this_, "disk/data/font/terminus/ter-v16b.psf");

		auto dobj = target(this_, this_.objDir ~ "/dcode.o", mapSources("loader/"), [consoleFont, consoleFontBold], Action.combine, dc);
		auto aobj = target(this_, this_.objDir ~ "/acode.o", mapSources("loader/", "*.S"), null, Action.combine, ac);

		this_.output["powerd"] = target(this_, this_.objDir ~ "/disk/boot/powerd.ldr", [TargetInput(dobj),
			TargetInput(aobj)], null, Action.combine, ld);
	});

	Project initrd = project("initrd", null, (Project this_) {
		import std.algorithm : map;
		import std.array : array;

		// dfmt off
		string[] files = [
			"initrd/data/dlogo.bmp"
		];
		// dfmt on

		auto cp = processor("cp $in $out");
		auto makeInitrd = processor("tar -c --posix -f $out -C $in .");

		auto initrdFiles = targetPhony(this_, files.map!(x => this_.objDir ~ "/" ~ x).array, files, null, Action.each, cp);

		this_.output["initrd"] = targetPhony(this_, this_.objDir ~ "/disk/boot/powernex-initrd.dsk",
			this_.objDir ~ "/initrd/", [initrdFiles], Action.combine, makeInitrd);
	});

	Project kernel = project("powernex.krl", null, (Project this_) {
		auto dc = processor("cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -Ikernel/src -I"
			~ this_.objDir ~ "/kernel/src -Jkernel/src -J" ~ this_.objDir ~ "/kernel/src -Jdisk/ -J" ~ this_.objDir
			~ "/disk -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/kernel -X -Xfdocs-kernel.json -of$out $in");
		/*auto dcHeader = processor(
			["cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -Ikernel/src -I" ~ this_.objDir ~ "/kernel/src -Jkernel/src -J"
			~ this_.objDir ~ "/kernel/src -Jdisk/ -J" ~ this_.objDir ~ "/disk -defaultlib= -debuglib= -version=bare_metal -debug=allocations -o- -Hf$out $in"]);*/
		auto ac = processor("cc/bin/x86_64-powernex-as --divide --64 -o $out $in");
		auto ld = processor("cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T kernel/src/kernel.ld");

		auto dobj = target(this_, this_.objDir ~ "/dcode.o", mapSources("kernel/"), null, Action.combine, dc);
		auto aobj = target(this_, this_.objDir ~ "/acode.o", mapSources("kernel/", "*.S"), null, Action.combine, ac);

		this_.output["powernex"] = target(this_, this_.objDir ~ "/disk/boot/powernex.krl", [TargetInput(dobj),
			TargetInput(aobj)], null, Action.combine, ld);
	});

	Project iso = project("powernex.iso", null, (Project this_) {
		import std.algorithm : map;
		import std.array : array;

		// dfmt off
		TargetInput[] bootFiles = [
			TargetInput(loader.output["powerd"]),
			TargetInput(kernel.output["powernex"]),
			TargetInput(initrd.output["initrd"])
		];
		// dfmt on

		auto cp = processor("cp $in $out");
		auto iso = processor("grub-mkrescue -d /usr/lib/grub/i386-pc -o $out $in");

		auto grubCfg = target(this_, this_.objDir ~ "/disk/boot/grub/grub.cfg", "disk/boot/grub/grub.cfg", null, Action.combine, cp);
		auto diskBoot = target(this_, this_.objDir ~ "/disk/boot", bootFiles, null, Action.combine, cp);
		auto disk = target(this_, this_.objDir ~ "/disk", null, [grubCfg, diskBoot], Action.combine, null);
		this_.output["iso"] = target(this_, this_.objDir ~ "/powernex.iso", [disk], null, Action.combine, iso);
	});

	compile(iso);
}

class Project {
	Project parent;
	string name;
	Target[string] output;

	string[string] vars;
	string[string] env;

	@property string objDir() {
		return (parent ? parent.objDir() : "objs") ~ "/" ~ name;
	}
}

Project project(T)(string name, Project parent, T init) if (__traits(compiles, init(parent))) {
	auto p = new Project;
	p.name = name;
	p.parent = parent;
	init(p);
	return p;
}

class Processor {
	string[] commands;

	string[string] vars;
	string[string] env;
}

Processor processor(Commands)(Commands commands, string[string] vars = null, string[string] env = null) {
	Processor p = new Processor;
	static if (is(Commands == string))
		p.commands = [commands];
	else
		p.commands = commands;
	p.vars = vars;
	p.env = env;
	return p;
}

enum Action {
	each,
	combine
}

alias TargetInput = Algebraic!(string, Project, Target);

class Target {
	Project parent;
	string[] output;
	TargetInput[] input;
	TargetInput[] dependencies;

	Action action;
	Processor processor;

	string[string] vars;
	string[string] env;

	bool isCached;
}

Target target(Project parent, string file) {
	import std.conv : to;

	Target t = new Target;
	t.parent = parent;

	t.output = [file];
	t.action = Action.each;

	t.isCached = true;
	return t;
}

Target target(Output, Input, Dependencies)(Project parent, Output output, Input input, Dependencies dependencies,
		Action action, Processor processor, string[string] vars = null, string[string] env = null) {
	import std.conv : to;

	Target t = new Target;
	t.parent = parent;

	void parse(T, X)(ref T output, X x) {
		static if (is(X == typeof(null)))
			output = null;
		else static if (is(X == XX[], XX) && !is(X == string))
			output = x.to!T;
		else
			output = [x].to!T;
	}

	parse(t.output, output);
	parse(t.input, input);
	parse(t.dependencies, dependencies);

	t.action = action;
	t.processor = processor;

	t.vars = vars;
	t.env = env;

	t.isCached = true;
	return t;
}

Target targetPhony(Output, Input, Dependencies)(Project parent, Output output, Input input, Dependencies dependencies,
		Action action, Processor processor, string[string] vars = null, string[string] env = null) {
	Target t = target(parent, output, input, dependencies, action, processor, vars, env);
	t.isCached = true;
	return t;
}

TargetInput[] mapSources(string rootFolder, string glob = "*.d") {
	import std.file : dirEntries, SpanMode;
	import std.algorithm : filter;

	TargetInput[] srcs;
	foreach (f; dirEntries(rootFolder, glob, SpanMode.breadth).filter!(x => !x.isDir))
		srcs ~= TargetInput(f.name);

	return srcs;
}

size_t indent = 0;
string _() {
	string o;
	auto i = indent;
	while (i && --i != 0)
		o ~= "#";
	return o;
}

void compile(string s) {
}

void compile(TargetInput ti) {
	ti.visit!((string s) => compile(s), (Project p) => compile(p), (Target t) => compile(t));
}

string toString(TargetInput ti) {
	import std.array : join;

	return ti.visit!((string s) => s, (Target t) => cast(string)t.output.join(" "), (Project p) => "");
}

void exec(string cmd) {
	import std.process : executeShell, wait;
	import core.stdc.stdlib : exit, EXIT_FAILURE;

	normal(_, "Executing: ", cmd, "\n");
	auto proc = executeShell(cmd);
	if (proc.status != 0) {
		error("\tProgram returned", proc.status, "\n", proc.output);
		exit(EXIT_FAILURE);
	} else
		good(proc.output);
}

void compile(Target t) {
	indent++;
	scope (exit)
		indent--;

	foreach (o; t.dependencies)
		compile(o);

	foreach (o; t.input)
		compile(o);

	foreach (o; t.output)
		compile(o);

	import std.array : array, replace;
	import std.algorithm : map, joiner;
	import std.file : mkdirRecurse;
	import std.string : lastIndexOf;

	if (!t.processor)
		return;
	if (t.action == Action.each) {
		assert(t.input.length == t.output.length);
		for (size_t i; i < t.input.length; i++)
			foreach (cmd; t.processor.commands) {
				string output = t.output[i];
				auto pos = output.lastIndexOf("/");
				if (pos > 0)
					mkdirRecurse(output[0 .. pos]);
				string c = cmd.replace("$in", t.input[i].toString).replace("$out", t.output[i]);
				exec(c);
			}
	} else {
		assert(t.output.length == 1);
		foreach (string cmd; t.processor.commands) {
			string output = t.output[0];
			auto pos = output.lastIndexOf("/");
			if (pos > 0)
				mkdirRecurse(output[0 .. pos]);
			string c = cmd.replace("$in", t.input.map!toString.joiner(" ").array).replace("$out", t.output[0]);
			exec(c);
		}
	}
}

void compile(Project p) {
	indent++;
	scope (exit)
		indent--;

	normal(_, "Project name: ", p.name, "\n");
	foreach (string k, Target v; p.output) {
		indent++;
		scope (exit)
			indent--;
		compile(v);

		import std.string : lastIndexOf;

		string name = v.output[0];
		string shortName = name[name.lastIndexOf("/") + 1 .. $];
		exec("ln -sf " ~ name ~ " " ~ shortName);
	}
}
