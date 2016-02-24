import std.stdio;

enum MAGIC = ['D', 'S', 'K', '0'];
enum Type : ulong {
	File,
	Folder
}

struct Initrd {
align(1):
	char[4] Magic;
	ulong Count;
}

struct InitrdEntry {
align(1):
	char[128] name;
	ulong offset;
	ulong size;
	Type type;
	ulong parent;

	string toString() const {
		import std.format : format;
		import std.string : fromStringz;

		return format(`InitrdEntry["%s", 0x%x, 0x%x, %s, %s]`, name.ptr.fromStringz, offset, size, type, parent);
	}
}

int main(string[] args) {
	assert(args.length == 3, "USAGE: <Initrd Folder> <Output>");

	File f = File(args[2], "wb");
	InitrdEntry[] entries;
	string[] fullFilename;

	addFiles(args[1], ulong.max, entries, fullFilename);

	writeln("The files that will be added");
	foreach (entry; entries)
		entry.writeln;

	ulong offset = Initrd.sizeof + InitrdEntry.sizeof * entries.length;
	offset = (offset + 0xF) & ~0xF;
	File[] fp;
	fp.length = entries.length;

	foreach (idx, ref entry; entries) {
		if (entry.type == Type.File) {
			fp[idx] = File(fullFilename[idx], "rb");
			entry.size = fp[idx].size;
			entry.offset = offset;
			offset += entry.size;
			offset = (offset + 0xF) & ~0xF;
		}
	}

	writeln("The correct sizes and offsets");
	foreach (entry; entries)
		entry.writeln;

	Initrd header = Initrd(MAGIC, entries.length);

	f.rawWrite((cast(ubyte*)&header)[0 .. Initrd.sizeof]);
	f.rawWrite((cast(ubyte*)entries.ptr)[0 .. InitrdEntry.sizeof * entries.length]);

	ubyte[16] nullbytes;

	foreach (idx, ref entry; entries) {
		long diff = cast(long)entry.offset - cast(long)f.size;
		if (diff > 0)
			f.rawWrite(nullbytes[0 .. diff]);
		if (entry.type == Type.File) {
			ubyte[] buf;
			buf.length = entry.size;
			if (buf.length)
				f.rawWrite(fp[idx].rawRead(buf));
			fp[idx].close();
		}
	}
	f.close();
	return 0;
}

auto strip(string name) {
	import core.stdc.string : strncpy;
	import std.string : toStringz;
	import std.algorithm.comparison : min;

	char[128] buf;
	strncpy(buf.ptr, name.toStringz, buf.length);
	return buf;
}

void addFiles(string path, ulong parent, ref InitrdEntry[] entries, ref string[] fullFilename) {
	import std.file;
	import std.path;

	foreach (entry; dirEntries(path, SpanMode.shallow)) {
		fullFilename ~= entry.name;
		if (entry.isFile)
			entries ~= InitrdEntry(entry.name.baseName.strip, 0, 0, Type.File, parent);
		else {
			ulong par = entries.length;
			entries ~= InitrdEntry(entry.name.baseName.strip, 0, 0, Type.Folder, parent);
			addFiles(entry.name, par, entries, fullFilename);
		}
	}
}
