#!/usr/bin/rdmd
import std.stdio;
import std.variant;

// dfmt off
void normal(Args...)(Args args)  { write("\x1b[39;1m", args, "\x1b[0m"); }
void good(Args...)(Args args)    { write("\x1b[33;1m", args, "\x1b[0m"); }
void warning(Args...)(Args args) { stderr.write("\x1b[31;1m", args, "\x1b[0m"); }
void error(Args...)(Args args)   { stderr.write("\x1b[37;41;1m", args, "\x1b[0m"); }
// dfmt on

void main() {
	//auto nativeDC = processor(["dmd -of$out -od" ~ objDir ~ "/utils/obj $in"]);

	Project loader = project("powerd.ldr", null, (Project this_) {
		auto dc = processor(
			["cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -color=on -debug -betterC -c -g -version=PowerD -Iloader/src -I" ~ this_.objDir ~ " -Jloader/src -J"
			~ this_.objDir
			~ " -Jdisk/ -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/loader -X -Xfdocs-loader.json -of$out $in"]);
		auto ac = processor(["cc/bin/x86_64-powernex-as --64 -o $out $in"]);
		auto ld = processor(["cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T loader/src/loader.ld -nostdlib"]);

		auto dobj = target(this_, mapSources("loader/"), [this_.objDir ~ "/dcode.o"], Action.combine, dc);
		auto aobj = target(this_, mapSources("loader/", "*.S"), [this_.objDir ~ "/acode.o"], Action.combine, ac);

		this_.output["powerd"] = target(this_, [TargetInput(dobj), TargetInput(aobj)], ["output/disk/boot/powerd.ldr"], Action.combine, ld);
	});

	Project resources = project("resources", null, (Project this_) {
		this_.output["consoleFont"] = targetPhony(this_, "disk/data/font/terminus/ter-v16n.psf");
		this_.output["consoleFontBold"] = targetPhony(this_, "disk/data/font/terminus/ter-v16b.psf");
	});

	Project kernel = project("powernex.krl", null, (Project this_) {
		auto dc = processor(["cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -Ikernel/src -I"
			~ this_.objDir ~ "/kernel/src -Jkernel/src -J" ~ this_.objDir ~ "/kernel/src -Jdisk/ -J" ~ this_.objDir
			~ "/disk -defaultlib= -debuglib= -version=bare_metal -debug=allocations -D -Dddocs/kernel -X -Xfdocs-kernel.json -of$out $in"]);
		/*auto dcHeader = processor(
			["cc/bin/powernex-dmd -m64 -dip25 -dip1000 -dw -vtls -color=on -fPIC -debug -c -g -Ikernel/src -I" ~ this_.objDir ~ "/kernel/src -Jkernel/src -J"
			~ this_.objDir ~ "/kernel/src -Jdisk/ -J" ~ this_.objDir ~ "/disk -defaultlib= -debuglib= -version=bare_metal -debug=allocations -o- -Hf$out $in"]);*/
		auto ac = processor(["cc/bin/x86_64-powernex-as --divide --64 -o $out $in"]);
		auto ld = processor(["cc/bin/x86_64-powernex-ld -o $out -z max-page-size=0x1000 $in -T kernel/src/kernel.ld"]);

		auto dobj = target(this_, mapSources("kernel/"), [this_.objDir ~ "/dcode.o"], Action.combine, dc);
		auto aobj = target(this_, mapSources("kernel/", "*.S"), [this_.objDir ~ "/acode.o"], Action.combine, ac);

		this_.output["powernex"] = target(this_, [TargetInput(dobj), TargetInput(aobj)],
			["output/disk/boot/powernex.ldr"], Action.combine, ld);
	});

	/*Project loader = project("utils/makeinitrdold", null, (Project this_) {
		this_.output["powerd"] = target(this_, ["utils/makeinitrd.d"], Action.combine, nativeDC);
	});*/

	compile(loader);
	compile(kernel);
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

Processor processor(string[] commands, string[string] vars = null, string[string] env = null) {
	Processor p = new Processor;
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
	TargetInput[] input;
	string[] output;

	Action action;
	Processor processor;

	string[string] vars;
	string[string] env;
}

Target target(Project parent, TargetInput[] input, string[] output, Action action, Processor processor,
		string[string] vars = null, string[string] env = null) {
	Target t = new Target;
	t.parent = parent;
	t.input = input;
	t.output = output;

	t.action = action;
	t.processor = processor;

	t.vars = vars;
	t.env = env;
	return t;
}

Target targetPhony(Project parent, string output, Processor processor = null, string[string] vars = null, string[string] env = null) {
	Target t = new Target;
	t.parent = parent;
	t.input = [TargetInput("")];
	t.output = [output];

	t.action = Action.each;
	t.processor = processor;

	t.vars = vars;
	t.env = env;
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
	while (--i != 0)
		o ~= "  ";
	return o;
}

void compile(string s) {
	indent++;
	scope (exit)
		indent--;

	normal(_, s, "\n");
}

void compile(TargetInput ti) {
	indent++;
	scope (exit)
		indent--;

	ti.visit!((string s) => compile(s), (Project p) => compile(p), (Target t) => compile(t));
}

string toString(TargetInput ti) {
	import std.array : join;

	return ti.visit!((string s) => s, (Target t) => cast(string)t.output.join(" "), (Project p) => "");
}

void compile(Target t) {
	indent++;
	scope (exit)
		indent--;

	normal(_, "Is a Target\n");
	normal(_, "Action: ", t.action, "\n");

	normal(_, "Input: \n");
	foreach (o; t.input)
		compile(o);

	normal(_, "Output: \n");
	foreach (o; t.output)
		compile(o);

	import std.process : spawnShell, wait;
	import std.array : array, replace;
	import std.algorithm : map, joiner;
	import std.file : mkdirRecurse;
	import std.string : lastIndexOf;

	if (t.action == Action.each) {
		assert(t.input.length == t.output.length);
		for (size_t i; i < t.input.length; i++)
			foreach (cmd; t.processor.commands) {
				string output = t.output[i];
				auto pos = output.lastIndexOf("/");
				if (pos > 0)
					mkdirRecurse(output[0 .. pos]);
				string c = cmd.replace("$in", t.input[i].toString).replace("$out", t.output[i]);
				normal(_, "Executing: ", c, "\n");
				wait(spawnShell(c));
			}
	} else {

		assert(t.output.length == 1);
		foreach (string cmd; t.processor.commands) {
			string output = t.output[0];
			auto pos = output.lastIndexOf("/");
			if (pos > 0)
				mkdirRecurse(output[0 .. pos]);
			string c = cmd.replace("$in", t.input.map!toString.joiner(" ").array).replace("$out", t.output[0]);
			normal(_, "Executing: ", c, "\n");
			wait(spawnShell(c));
		}
	}
}

void compile(Project p) {
	indent++;
	scope (exit)
		indent--;

	normal(_, "Project name: ", p.name, "\n");
	normal(_, "Output: \n");
	foreach (k, v; p.output) {
		indent++;
		scope (exit)
			indent--;
		normal(_, "Key: ", k, "\n");
		compile(v);
	}
}
