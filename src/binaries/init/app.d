module app;

import core.sys.powernex.io;

__gshared string varGSHARED = "1: varGSHARED";
shared string varSHARED = "2: varSHARED";
string varTLS = "3: varTLS";

int main(string[] args) {
	write(StdFile.stdout, "Hello world from Userspace!\n");

	write(StdFile.stdout, "The args are: \n");

	foreach (arg; args) {
		write(StdFile.stdout, arg);
		write(StdFile.stdout, "\n");
	}

	write(StdFile.stdout, "varGSHARED: ");
	write(StdFile.stdout, varGSHARED);
	write(StdFile.stdout, "\n");
	write(StdFile.stdout, "varSHARED: ");
	write(StdFile.stdout, varSHARED);
	write(StdFile.stdout, "\n");
	write(StdFile.stdout, "varTLS: ");
	write(StdFile.stdout, varTLS);
	write(StdFile.stdout, "\n");

	varGSHARED = "===gshared===";
	varSHARED = "===shared===";
	varTLS = "===tls===";

	write(StdFile.stdout, "varGSHARED: ");
	write(StdFile.stdout, varGSHARED);
	write(StdFile.stdout, "\n");
	write(StdFile.stdout, "varSHARED: ");
	write(StdFile.stdout, varSHARED);
	write(StdFile.stdout, "\n");
	write(StdFile.stdout, "varTLS: ");
	write(StdFile.stdout, varTLS);
	write(StdFile.stdout, "\n");

	return cast(int)(0xC0DE_0000 + args.length);
}
