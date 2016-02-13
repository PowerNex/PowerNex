import std.stdio;
import std.process;
import std.demangle;
import std.algorithm.iteration;
import std.array;
import std.conv;

struct SymbolTable {
align(1):
	char[] Magic = ['D', 'S', 'Y', 'M'];
	ulong Count;
}

struct Line {
align(1):
	this(ulong start, ulong end, string name) {
		Start = start;
		End = end;
		NameLength = name.length;
		Name = name.dup;
	}

	ulong Start;
	ulong End;
	ulong NameLength;
	char[] Name;
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

	lines.each!(x => table.Count++);

	output.rawWrite(table.Magic);
	output.rawWrite((cast(ubyte*)&table.Count)[0 .. ulong.sizeof]);

	foreach (Line line; lines) {
		output.rawWrite((cast(ubyte*)&line.Start)[0 .. ulong.sizeof]);
		output.rawWrite((cast(ubyte*)&line.End)[0 .. ulong.sizeof]);
		output.rawWrite((cast(ubyte*)&line.NameLength)[0 .. ulong.sizeof]);
		output.rawWrite(line.Name);
	}

	output.close();

	return 0;
}
