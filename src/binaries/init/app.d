module app;

import std.stdio;
import core.sys.powernex.process;

__gshared string varGSHARED = "1: varGSHARED";
string varTLS = "2: varTLS";
double f = 13.37;

int main(string[] args) {
	writeln("Hello world from Userspace!");
	writeln("The args are:");

	foreach (arg; args)
		writeln("\t", arg);

	writeln("varGSHARED: ", varGSHARED);
	writeln("varTLS: ", varTLS);
	writeln("f: ", f);

	varGSHARED = "===gshared===";
	varTLS = "===tls===";
	f *= 4.20;

	writeln("varGSHARED: ", varGSHARED);
	writeln("varTLS: ", varTLS);
	writeln("f: ", f);

	writeln("Will fork!");
	PID prevChild = 0;
	for (size_t i = 0; i < 8; i++) {
		PID pid = fork();
		if (pid == 0) {
			writeln("Hello I'm the child! prevChild is: ", prevChild);
			return cast(int)i;
		} else
			writeln("Hello I'm the parent and the child is '", pid, "' !");
		prevChild = pid;
	}

	return cast(int)(0xC0DE_0000 + args.length);
}
