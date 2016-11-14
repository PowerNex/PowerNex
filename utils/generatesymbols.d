module generatesymbols;

import std.stdio;
import std.process;
import std.demangle;
import std.algorithm.iteration;
import std.array;
import std.conv;

struct SymbolTable {
align(1):
	char[] magic = ['D', 'S', 'Y', 'M'];
	ulong count;
}

struct Line {
align(1):
	this(ulong start, ulong end, string name) {
		this.start = start;
		this.end = end;
		this.nameLength = name.length;
		this.name = name.dup;
	}

	ulong start;
	ulong end;
	ulong nameLength;
	char[] name;
}

int main(string[] args) {
	assert(args.length == 3);
	auto pipes = pipeProcess(["sh", "-c", `readelf -W -s ` ~ args[1] ~ ` | grep "FUNC" |  awk -F" " '{ print $2 " " $3 " " $8}'`]);

	File output = File(args[2], "wb");
	SymbolTable table;

	//dfmt off
	auto lines = pipes.stdout.byLine
		.map!(split)
		.map!(x => Line(to!ulong(x[0], 16), to!ulong(x[0], 16) + to!ulong(x[1]), demangle(cast(string)x[2])))
		.array;
	//dfmt on

	lines.each!(x => table.count++);

	output.rawWrite(table.magic);
	output.rawWrite((cast(ubyte*)&table.count)[0 .. ulong.sizeof]);

	foreach (Line line; lines) {
		output.rawWrite((cast(ubyte*)&line.start)[0 .. ulong.sizeof]);
		output.rawWrite((cast(ubyte*)&line.end)[0 .. ulong.sizeof]);
		output.rawWrite((cast(ubyte*)&line.nameLength)[0 .. ulong.sizeof]);
		output.rawWrite(line.name);
	}

	output.close();

	return 0;
}
