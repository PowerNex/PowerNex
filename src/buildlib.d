module src.buildlib;

import std.stdio : write, writeln, stderr;
import std.variant : Algebraic, visit;
import std.datetime : SysTime;
import std.file : DirEntry;
import std.algorithm : map;
import std.range : chain;
import std.array : array, replace;

// dfmt off
void normal(Args...)(Args args)  { write("\x1b[39;1m", args, "\x1b[0m"); }
void good(Args...)(Args args)    { write("\x1b[32;1m", args, "\x1b[0m"); }
void warning(Args...)(Args args) { stderr.write("\x1b[31;1m", args, "\x1b[0m"); }
void error(Args...)(Args args)   { stderr.write("\x1b[37;41;1m", args, "\x1b[0m"); }
// dfmt on

static files(string Prefix, Files...) = [Files].map!(x => new Target(Path(Prefix ~ x, false), true, false, null, null, null)).array();

/// SemVer version format: Major.Minor.Patch
struct SemVer {
	size_t major; /// The major version
	size_t minor; /// The minor version
	size_t patch; /// The patch version

	string toString() {
		import std.format : format;

		return format("%s.%s.%s", major, minor, patch);
	}
}

class Project {
	string name;
	SemVer version_;
	Target[string] outputs;

	Project[] dependencies;

	this(string name, SemVer version_, Target[string] outputs = null) {
		this.name = name;
		this.version_ = version_;
		this.outputs = outputs;
	}

	//TODO: string[string] env;

	void finalize() {
		void updatePath(Target t) {
			if (t.state == Target.State.visualizing)
				return;

			t.state = Target.State.visualizing;
			if (t.output.appendObjDir) {
				t.output = objDir ~ t.output;
				t.output.appendObjDir = false;
			}

			foreach (Target tt; chain(t.input, t.dependencies))
				updatePath(tt);
		}

		foreach (_, Target t; outputs)
			updatePath(t);
	}

	@property string objDir() {
		import std.format : format;

		return format("build/objs/%s/", name);
	}
}

private Project[string] _globalProjects;
void registerProject(Project p) {
	p.finalize();
	_globalProjects[p.name] = p;
}

Project findDependency(string name) {
	auto p = name in _globalProjects;
	assert(p, "Could not find project: " ~ name);
	return *p;
}

static struct Processor {
	@disable this();
	static auto combine(string cmd, string[string] env = null) {
		class CombineProcessor {
			string command;
			string[string] env;

			this(string command, string[string] env = null) {
				this.command = command;
			}

			Target opCall(string output, bool phony, Target[] input, Target[] dependencies = null) {
				return opCall(output.Path, phony, input, dependencies);
			}

			Target opCall(Path output, bool phony, Target[] input, Target[] dependencies = null) {
				return new Target(output, false, phony, input, dependencies, command);
			}
		}

		return new CombineProcessor(cmd, env);
	}
}

struct Path {
	string path;
	bool appendObjDir = true;

	alias path this;
}

class Target {
	enum State {
		none,
		visualizing,
		buildInfo
	}

	Path output;
	bool leaf;
	bool isPhony;
	Target[] input;
	Target[] dependencies;

	private string _makeCommand;
	@property string makeCommand() {
		import std.algorithm : joiner;
		import std.string : strip;

		return _makeCommand.replace("$out$", output.path).replace("$in$", input.map!"a.output".joiner(" ").array).strip;
	}

	State state = State.none;

	this(string output, bool leaf, bool isPhony, Target[] input, Target[] dependencies, string makeCommand) {
		this(output.Path, leaf, isPhony, input, dependencies, makeCommand);
	}

	this(Path output, bool leaf, bool isPhony, Target[] input, Target[] dependencies, string makeCommand) {
		this.output = output;
		this.leaf = leaf;
		this.isPhony = isPhony;
		this.input = input;
		this.dependencies = dependencies;
		this._makeCommand = makeCommand;
	}

	bool needRebuild( /*ref const(SysTime) parentTimeLastModified*/ ) {
		import std.file : DirEntry, exists;

		if (isPhony)
			return true;
		if (!exists(output))
			return true;

		/*bool rebuild = DirEntry(output).timeLastModified > parentTimeLastModified;
		if (DirEntry(output).timeLastModified > parentTimeLastModified)
			writeln("\ttimeLastModified > parentTimeLastModified: ", DirEntry(output).timeLastModified, " > ", parentTimeLastModified, " => true");
		return rebuild;*/
		return false;
	}
}

void exec(Target t) {
	import std.process : executeShell, wait;
	import core.stdc.stdlib : exit, EXIT_FAILURE;

	string cmd = t.makeCommand;
	if (!cmd.length)
		return;

	import std.file : mkdirRecurse;
	import std.path : dirName;
	import std.string : indexOf;

	with (t.output)
		mkdirRecurse(path[$ - 1] == '/' ? path : dirName(path));

	normal("Executing: ", cmd, "\n");
	auto proc = executeShell(cmd);
	if (proc.status != 0 || proc.output.indexOf("is thread local") != -1) {
		error("====> Program returned: ", proc.status, " <====\n", proc.output);
		exit(EXIT_FAILURE);
	} else
		good(proc.output);
}

struct BuildInfo {
	Project project;
	Target[] targets; // TODO: Replace with something else, when multithreading
}

BuildInfo gatherBuildInfo(Project p) {
	BuildInfo bi;
	bi.project = p;

	bool targetCount(Target t, ref BuildInfo bi) {
		if (t.state == Target.State.buildInfo)
			return false;

		t.state = Target.State.buildInfo;

		bool needRebuild = t.needRebuild;
		foreach (Target tt; chain(t.input, t.dependencies))
			needRebuild |= targetCount(tt, bi);

		if (needRebuild) {
			bi.targets ~= t;
			warning("\tWill rebuild: ", t.output.path, "\n");
		}
		return needRebuild;
	}

	void projectTargetCount(Project p, ref BuildInfo bi) {
		foreach (_, Target t; p.outputs)
			targetCount(t, bi);
	}

	foreach (Project dep; p.dependencies)
		projectTargetCount(dep, bi);
	projectTargetCount(p, bi);

	return bi;
}

void buildProject(BuildInfo bi) {
	foreach (idx, Target t; bi.targets) {
		exec(t);
	}
}

void dotGraph(Project project) {
	import std.stdio : File;
	import std.process : pipeShell, Redirect, wait;

	bool[size_t] havePrinted;

	void print(File output, Target target, Project project = null) {

		if (project)
			output.writefln("\tp_%X -> t_%X;", cast(void*)project, cast(void*)target);

		output.writefln("\tt_%X[style=filled,fillcolor=%s,label=\"%4$s%3$s%4$s\"];", cast(void*)target, project ? "yellow"
				: "cyan", target.output, target.needRebuild ? "**" : "");

		if (cast(size_t)cast(void*)target in havePrinted)
			return;
		havePrinted[cast(size_t)cast(void*)target] = true;

		void printRequirements(Target[] arr) {
			import std.algorithm;

			if (!arr)
				return;
			auto leafs = arr.filter!"a.leaf";
			auto targets = arr.filter!"!a.leaf";
			if (!leafs.empty) {
				output.writef("\tt_%X_%X[style=filled,fillcolor=green,label=\"Source|{", cast(void*)target, arr.ptr);
				size_t idx;
				foreach (Target t; leafs)
					output.write(idx++ ? "|" : "", t.output);
				output.writeln("}\"];");
				output.writefln("\tt_%X -> t_%X_%X;", cast(void*)target, cast(void*)target, arr.ptr);
			}
			foreach (Target t; targets) {
				output.writefln("\tt_%X -> t_%X;", cast(void*)target, cast(void*)t);
				print(output, t);
			}
		}

		printRequirements(target.input);
		printRequirements(target.dependencies);
	}

	bool[Project] hasWritten;
	hasWritten[project] = true;
	with (pipeShell("tee /dev/stderr | /usr/bin/dot -Tx11", Redirect.stdin)) {
		scope (exit)
			wait(pid);
		stdin.writeln("digraph Build {");
		stdin.writeln("\tnode [shape=record];");
		stdin.writefln("\tp_%X[style=filled,fillcolor=pink,label=\"%s\"];", cast(void*)project, project.name);
		foreach (idx, t; project.outputs)
			print(stdin, t, project);

		void writeDependencies(Project current) {
			foreach (Project p; current.dependencies) {
				stdin.writefln("\tp_%X -> p_%X;", cast(void*)current, cast(void*)p);
				if (p in hasWritten)
					continue;
				hasWritten[p] = true;

				writeDependencies(p);

				stdin.writefln("\tp_%X[style=filled,fillcolor=red,label=\"%s\"];", cast(void*)p, p.name);
				foreach (idx, t; p.outputs)
					print(stdin, t, p);
			}
		}

		writeDependencies(project);
		stdin.writeln("}");
		stdin.flush();
		stdin.close();
	}
}
