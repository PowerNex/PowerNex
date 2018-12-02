module app;

import core.sys.powernex.io;

int main(string[] args) {
	write(StdFile.stdout, "Hello world from Userspace!");

	write(StdFile.stdout, "The args are: ");

	foreach (arg; args)
		write(StdFile.stdout, arg);

	return cast(int)(0xC0DE_0000 + args.length);
}
