module log;

import std.stdio;
import std.file;
import core.thread;
import core.time : msecs;
import core.sys.posix.sys.stat;
import std.string;
import std.process;

ProcessPipes findAddressKernel;
ProcessPipes findAddressLoader;

void reloadProcesses() {
	if (findAddressLoader.pid)
		findAddressLoader.pid.kill;
	if (findAddressKernel.pid)
		findAddressKernel.pid.kill;

	findAddressLoader = pipeShell("addr2line -e build/objs/PowerNexOS/disk/boot/powerd.ldr -i -p -s -f | ddemangle");
	findAddressKernel = pipeShell("addr2line -e build/objs/PowerNexOS/disk/boot/powernex.krl -i -p -s -f | ddemangle");
}

int main(string[] args) {
	if (args.length < 2) {
		writeln("Usage: ", args[0], " <Log file>");
		return 1;
	}
	reloadProcesses();

	while (true) {
		while (!args[1].exists)
			Thread.sleep(100.msecs);

		try {
			File f = File(args[1]);
			scope (exit)
				f.close();

			string tmpLine;
			while (!f.error) {
				string line;
				while ((line = f.readln()) !is null) {
					if (tmpLine.length) {
						line = tmpLine ~ line;
						tmpLine = null;
					}
					if (line[$ - 1] == '\n')
						line.processLine;
					else
						tmpLine = line;
				}
				while (f.eof) {
					Thread.sleep(1.msecs);
					f.seek(0, SEEK_CUR);
					size_t current = f.tell();
					stat_t status;
					stat(args[1].toStringz, &status);
					if (status.st_size < current) {
						f.seek(0, SEEK_SET);
						if (tmpLine) {
							writeln(tmpLine);
							tmpLine = null;
						}
						writeln("\n\nFile got truncated\n\n");
						reloadProcesses();
					}
				}
			}

			Thread.sleep(10.msecs);
		} catch (Exception e) {
			stderr.writeln("File error");
			stderr.writeln(e);
		}
	}

	return 1;
}

string[char] colorMap;
shared static this() {
	colorMap = ['&' : "0;33", '+' : "1;32", '*' : "1;36", '#' : "1;33", '-' : "0;31", '!' : "1;31"];
}

void processLine(string line) {
	import std.regex;

	auto colorRx = ctRegex!(`(?:\[(\d+)\]\[(.)\] )?(.*)`);
	auto matchColor = line.matchFirst(colorRx);
	if (matchColor.empty) {
		write(line);
		return;
	}

	if (matchColor[1].length)
		write('[', matchColor[1], ']');
	if (matchColor[2].length) {
		write('[', matchColor[2], ']');
		if (string* color = matchColor[2][0] in colorMap)
			write("\x1b[", *color, "m");
		write(' ');
	}

	{
		auto stackTractRx = ctRegex!(`(?:  \[Function: (0x[0-9A-F]{16})\] (.*)!)(.*)`);
		auto matchStack = matchColor[3].matchFirst(stackTractRx);
		if (matchStack.empty)
			write(matchColor[3]);
		else {
			write("  [\x1b[1;33m", matchStack[1], "\x1b[0m] \x1b[0;34m", matchStack[2], "\x1b[0m!");

			if (auto _ = findAddressLoader.getAddressLine(matchStack[1]))
				write("\x1b[1;32m", _, "\x1b[0m");
			else if (auto _ = findAddressKernel.getAddressLine(matchStack[1]))
				write("\x1b[1;32m", _, "\x1b[0m");
			else
				write("*TODO: findAddress*");

			write(" (", matchStack[3], ")");

		}
	}

	writeln("\x1b[0m");
}

string getAddressLine(ProcessPipes pp, string str) {
	pp.stdin.writeln(str);
	pp.stdin.flush();
	string output = pp.stdout.readln()[0 .. $ - 1];
	if (output == "?? ??:0")
		return null;
	return output;
}
