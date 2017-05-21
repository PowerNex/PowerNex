import std.stdio : writefln;
import std.conv : to;

int main(string[] args) {
	foreach (arg; args[1 .. $]) {
		if (arg.length < 2)
			continue;
		if (arg[0 .. 2] == "0x")
			arg = arg[2 .. $];
		ulong vAddr = arg.to!ulong(16);

		const ulong pml4 = (vAddr >> 39) & 0x1FF;
		const ulong pml3 = (vAddr >> 30) & 0x1FF;
		const ulong pml2 = (vAddr >> 21) & 0x1FF;
		const ulong pml1 = (vAddr >> 12) & 0x1FF;
		const ulong offset = (vAddr >> 0) & 0xFFF;

		writefln("vAddr: 0x%X", vAddr);
		writefln("\tPML4: 0x%X", pml4);
		writefln("\tPML3: 0x%X", pml3);
		writefln("\tPML2: 0x%X", pml2);
		writefln("\tPML1: 0x%X", pml1);
		writefln("\tOffset: 0x%X", offset);

		ulong rebuild;
		if ((pml4 >> 8) & 0x1)
			rebuild = 0xFFFFUL << 48UL;

		rebuild |= pml4 << 39UL | pml3 << 30UL | pml2 << 21UL | pml1 << 12UL | offset;

		writefln("\tRebuild: 0x%X", rebuild);
		if (rebuild != vAddr)
			writefln("\t\tOriginal address is invalid!");
	}
	return 0;
}
