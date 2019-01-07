module app;

import std.stdio;

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

	return cast(int)(0xC0DE_0000 + args.length);
}
