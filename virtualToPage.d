import std.stdio;
import std.conv;
import std.string;

immutable ENTRY_PER_TABLE = 0x1000/8;

int main(string[] args) {
	if (args.length < 2) {
		writeln(args[0], ": <ADDRESS> [<ADDRESS2> [...]]");
		writeln("\tThis will translate all the addreses to their PageTable IDs");
		return 0;
	}

	foreach (string arg; args[1 .. $]) {
		assert(arg.startsWith("0x"));
		ulong virt = toImpl!ulong(arg[2 .. $], 16);

		auto pageTable            = (virt >> 11) & 0xFF;
		auto pageDirectory        = (virt >> 20) & 0xFF;
		auto pageDirectoryPointer = (virt >> 29) & 0xFF;
		auto pageMapLevel4        = (virt >> 38) & 0xFF;
		auto signExtended         = (virt >> 47) & 0xFF;

		writefln("Virtual address:        0x%X", virt);
		writefln("  PageTable:            0x%X", pageTable);
		writefln("  PageDirectory:        0x%X", pageDirectory);
		writefln("  PageDirectoryPointer: 0x%X", pageDirectoryPointer);
		writefln("  PageMapLevel4:        0x%X", pageMapLevel4);
		writefln("  SignExtended:         0x%X", signExtended);
		writeln();
	}
	return 0;
}
