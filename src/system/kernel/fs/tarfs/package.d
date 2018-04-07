/**
 * Implementation of a test filesystem
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.tarfs;

public import fs;
public import fs.tarfs.block;
public import fs.tarfs.node;
public import fs.tarfs.supernode;

/// Tar header for the POSIX ustar version
@safe package struct TarHeader {
	enum size_t HeaderSize = 512;
	enum char[6] Magic = "ustar\0";
	enum char[2] Version = "00";

	char[100] name; /// The full path for the file
	char[8] mode; /// Entry mode (octal number in ASCII)
	char[8] uid; /// Owner user id (octal number in ASCII)
	char[8] gid; /// Owner group id (octal number in ASCII)
	char[12] size; /// Size of entry (octal number in ASCII)
	char[12] mtime; /// Modification time of file(octal number in ASCII)
	char[8] checksum; /// Header checksum (octal number in ASCII) (6 octal number + space + \0)
	enum TypeFlag : char {
		file = '0',
		hardLink = '1',
		symbolicLink = '2',
		charDevice = '3',
		blockDevice = '4',
		directory = '5',
		fifo = '6',
		reserved = '7',

		paxGlobalExtendedHeader = 'g',
		paxExtendedHeader = 'x'
	}

	TypeFlag typeFlag; /// The type of the entry
	char[100] linkname; /// If the entry is a hardLink, this is the name of the file the hardlink points to.
	char[6] magic; /// Needs to match _tarMagic
	char[2] version_; /// Needs to match _tarVersion
	char[32] uname; /// Owner user name
	char[32] gname; /// Owner group name
	char[8] devmajor; /// Major number for charDevice or blockDevice
	char[8] devminor; /// Major number for charDevice or blockDevice
	char[155] prefix; /// If not empty, Prepend this to name with a '/' between
	private char[12] pad; /// Padding

	@property bool isNull() @trusted {
		foreach (ubyte b; (cast(ubyte*)cast(void*)&this)[0 .. HeaderSize])
			if (b)
				return false;
		return true;
	}

	@property bool checksumValid() @trusted {
		ptrdiff_t oldChecksum = checksum.toNumber;

		{
			ptrdiff_t chksum;
			foreach (b; (cast(ubyte*)&this)[0 .. checksum.offsetof])
				chksum += b;
			foreach (b; 0 .. checksum.length)
				chksum += cast(ubyte)' ';
			foreach (b; (cast(ubyte*)&this)[checksum.offsetof + checksum.length .. HeaderSize])
				chksum += b;

			if (oldChecksum == chksum)
				return true;
		}
		{
			size_t chksum;
			foreach (b; (cast(byte*)&this)[0 .. checksum.offsetof])
				chksum += b;
			foreach (b; 0 .. checksum.length)
				chksum += cast(byte)' ';
			foreach (b; (cast(byte*)&this)[checksum.offsetof + checksum.length .. HeaderSize])
				chksum += b;

			return oldChecksum == chksum;
		}
	}
}

@safe package struct PaxHeader {
	ptrdiff_t fileSize;
}

@safe package ptrdiff_t toNumber(const(char)[] num) {
	ptrdiff_t result;
	foreach (char c; num) {
		if (c < '0' || c > '9')
			break;
		result = result * 8 + (c - '0');
	}
	return result;
}

@safe package FSNode.Type toNodeType(TarHeader.TypeFlag type) {
	switch (type) with (TarHeader.TypeFlag) {
	case file:
		return FSNode.Type.file;
	case directory:
		return FSNode.Type.directory;
	case symbolicLink:
		return FSNode.Type.symbolicLink;
	case hardLink:
		return FSNode.Type.hardLink;

	default:
		return FSNode.Type.unknown;
	}
}
