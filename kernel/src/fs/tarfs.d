module fs.tarfs;

import fs;

import data.address;
import data.container;
import data.string_;
import memory.ref_;
import memory.allocator;

import io.log : log;

/// Tar header for the POSIX ustar version
struct TarHeader {
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

	@property bool checksumValid() {
		import io.log : log;

		ssize_t oldChecksum = checksum.toNumber;

		{
			ssize_t chksum;
			foreach (b; (cast(ubyte*)&this)[0 .. checksum.offsetof])
				chksum += b;
			foreach (b; 0 .. checksum.length)
				chksum += cast(ubyte)' ';
			foreach (b; (cast(ubyte*)&this)[checksum.offsetof + checksum.length .. _tarHeaderSize])
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
			foreach (b; (cast(byte*)&this)[checksum.offsetof + checksum.length .. _tarHeaderSize])
				chksum += b;

			return oldChecksum == chksum;
		}
	}
}

struct PaxHeader {
	ssize_t fileSize;
}

private enum size_t _tarHeaderSize = 512;
private enum char[6] _tarMagic = "ustar\0";
private enum char[2] _tarVersion = "00";

private ssize_t toNumber(const(char)[] num) {
	ssize_t result;
	foreach (char c; num) {
		if (c < '0' || c > '9')
			break;
		result = result * 8 + (c - '0');
	}
	return result;
}

private NodeType toNodeType(TarHeader.TypeFlag type) {
	switch (type) with (TarHeader.TypeFlag) {
	case file:
		return NodeType.file;
	case directory:
		return NodeType.directory;
	case symbolicLink:
		return NodeType.symlink;
	case hardLink:
		return NodeType.hardlink;
	case fifo:
		return NodeType.fifo;

	case charDevice:
	case blockDevice:
	case reserved:
	default:
		return NodeType.file;
	}
}

class TarRootNode : VNode {
public:
	this(FileSystem fs, FSNodeID id, FSNodeID parent) {
		this.id = id;
		this.type = NodeType.directory;
		this.fs = fs;
		this.mode = makeMode(7, 7, 5);

		this.name = "TarFS";

		_entries = kernelAllocator.makeRef!DirectoryEntryList(kernelAllocator);
		(*_entries).put(DirectoryEntry(fs, id, "."));
		(*_entries).put(DirectoryEntry(fs, parent, ".."));
	}

	override IOStatus chmod(ushort mode) {
		this.mode = mode;
		return IOStatus.success;
	}

	override IOStatus chown(long uid, long gid) {
		this.uid = uid;
		this.gid = gid;
		return IOStatus.success;
	}

	override IOStatus link(in string name, Ref!VNode node) {
		(*_entries).put(DirectoryEntry(fs, (*node).id, name));
		return IOStatus.success;
	}

	override IOStatus unlink(in string name) {
		foreach (DirectoryEntry e; (*_entries))
			if (e.name == name) {
				(*_entries).remove(e.id);
				return IOStatus.success;
			}
		return -IOStatus.notFound;
	}

	override IOStatus readLink(out string path) {
		return -IOStatus.isNotSymlink;
	}

	override IOStatus mount(in string name, Ref!FileSystem filesystem) {
		TarFS tarfs = cast(TarFS)fs;
		if (!tarfs)
			return -IOStatus.wrongFileSystem;
		Ref!VNode node = tarfs._mount(id, filesystem);
		if (!node)
			return -IOStatus.unknownError; //TODO:

		IOStatus ret = link(name, node);
		if (ret)
			tarfs._umount(node);

		return ret;
	}

	override IOStatus umount(in string name) {
		TarFS tarfs = cast(TarFS)fs;
		if (!tarfs)
			return -IOStatus.wrongFileSystem;
		FSNodeID id = 0; // Can't use unlink, because we need the ID of the entry
		foreach (idx, entry; (*_entries))
			if (entry.name == name) {
				id = entry.id;
				(*_entries).remove(idx);
				goto done;
			}

		return -IOStatus.notFound;

	done:
		Ref!VNode node = fs.getNode(id);
		if (!node)
			return -IOStatus.notFound;

		tarfs._umount(node);
		return IOStatus.success;
	}

	override IOStatus open(out NodeContext fd, FileDescriptorMode mode) {
		return -IOStatus.isNotFile;
	}

	override IOStatus close(in NodeContext fd) {
		return -IOStatus.isNotFile;
	}

	override IOStatus read(ref NodeContext fd, ubyte[] buffer) {
		return -IOStatus.isNotFile;
	}

	override IOStatus write(ref NodeContext fd, in ubyte[] buffer) {
		return -IOStatus.isNotFile;
	}

	override IOStatus duplicate(ref NodeContext fd, out NodeContext copy) {
		return -IOStatus.isNotFile;
	}

	override IOStatus dirEntries(out Ref!DirectoryEntryRange entriesRange) {
		entriesRange = cast(Ref!DirectoryEntryRange)kernelAllocator.makeRef!DefaultDirectoryEntryRange(_entries);
		return IOStatus.success;
	}

	override IOStatus mkdir(in string name, ushort mode) {
		return -IOStatus.notImplemented;
	}

	override IOStatus rmdir(in string name) {
		return -IOStatus.notImplemented;
	}

	override IOStatus ioctl(in NodeContext fd, size_t key, size_t value) {
		return -IOStatus.notImplemented;
	}

	override IOStatus accept(in NodeContext fd, out NodeContext client) {
		return -IOStatus.isNotSocket;
	}

private:
	Ref!DirectoryEntryList _entries;
}

class TarVNode : VNode {
public:
	this(FileSystem fs, FSNodeID id, FSNodeID parent, TarHeader* header, PaxHeader* paxHeader) {
		this.id = id;
		this.type = header.typeFlag.toNodeType;
		this.fs = fs;
		this.mode = makeMode(5, 5, 5); //RX/RX/RX
		this.size = paxHeader.fileSize ? paxHeader.fileSize : header.size.toNumber;

		this.name = header.name.fromStringz;
		name = name[name.indexOfLast('/') + 1 .. $];

		if (type == NodeType.file)
			_data = (header.VirtAddress + _tarHeaderSize).ptr!ubyte[0 .. size];
		else if (type == NodeType.directory) {
			_entries = makeRef!DirectoryEntryList(kernelAllocator, kernelAllocator);
			(*_entries).put(DirectoryEntry(fs, id, "."));
			(*_entries).put(DirectoryEntry(fs, parent, ".."));
		} else
			assert(0);
	}

	override IOStatus chmod(ushort mode) {
		this.mode = mode;
		return IOStatus.success;
	}

	override IOStatus chown(long uid, long gid) {
		this.uid = uid;
		this.gid = gid;
		return IOStatus.success;
	}

	override IOStatus link(in string name, Ref!VNode node) {
		if (type == NodeType.file)
			return -IOStatus.isNotDirectory;
		(*_entries).put(DirectoryEntry(fs, (*node).id, name));
		return IOStatus.success;
	}

	override IOStatus unlink(in string name) {
		if (type == NodeType.file)
			return -IOStatus.isNotDirectory;
		foreach (DirectoryEntry e; (*_entries))
			if (e.name == name) {
				(*_entries).remove(e.id);
				return IOStatus.success;
			}
		return -IOStatus.notFound;
	}

	override IOStatus readLink(out string path) {
		return -IOStatus.isNotSymlink;
	}

	override IOStatus mount(in string name, Ref!FileSystem filesystem) {
		TarFS tarfs = cast(TarFS)fs;
		if (!tarfs)
			return -IOStatus.wrongFileSystem;
		Ref!VNode node = tarfs._mount(id, filesystem);
		if (!node)
			return -IOStatus.unknownError; //TODO:

		IOStatus ret = link(name, node);
		if (ret)
			tarfs._umount(node);

		return ret;
	}

	override IOStatus umount(in string name) {
		TarFS tarfs = cast(TarFS)fs;
		if (!tarfs)
			return -IOStatus.wrongFileSystem;
		FSNodeID id = 0; // Can't use unlink, because we need the ID of the entry
		foreach (idx, entry; (*_entries))
			if (entry.name == name) {
				id = entry.id;
				(*_entries).remove(idx);
				goto done;
			}

		return -IOStatus.notFound;

	done:
		Ref!VNode node = fs.getNode(id);
		if (!node)
			return -IOStatus.notFound;

		tarfs._umount(node);
		return IOStatus.success;
	}

	override IOStatus open(out NodeContext fd, FileDescriptorMode mode) {
		if (type == NodeType.directory)
			return -IOStatus.isNotFile;

		fd = NodeContext(this, 0);
		return IOStatus.success;
	}

	override IOStatus close(in NodeContext fd) {
		return type == NodeType.file ? IOStatus.success : -IOStatus.isNotFile;
	}

	override IOStatus read(ref NodeContext fd, ubyte[] buffer) {
		if (type == NodeType.directory)
			return -IOStatus.isNotFile;
		if (fd.offset >= size)
			return IOStatus.success;

		size_t end = fd.offset + buffer.length;
		if (end > size)
			end = size;

		foreach (idx, ref b; _data[fd.offset .. end])
			buffer[idx] = b;

		size_t amount = end - fd.offset;
		fd.offset += amount;

		return cast(IOStatus)amount;
	}

	override IOStatus write(ref NodeContext fd, in ubyte[] buffer) {
		return -IOStatus.notImplemented;
	}

	override IOStatus duplicate(ref NodeContext fd, out NodeContext copy) {
		if (type == NodeType.file) {
			copy = fd;
			return IOStatus.success;
		} else
			return -IOStatus.isNotFile;
	}

	override IOStatus dirEntries(out Ref!DirectoryEntryRange entriesRange) {
		if (type != NodeType.directory)
			return -IOStatus.isNotDirectory;

		entriesRange = cast(Ref!DirectoryEntryRange)kernelAllocator.makeRef!DefaultDirectoryEntryRange(_entries);
		return IOStatus.success;
	}

	override IOStatus mkdir(in string name, ushort mode) {
		return -IOStatus.notImplemented;
	}

	override IOStatus rmdir(in string name) {
		return -IOStatus.notImplemented;
	}

	override IOStatus ioctl(in NodeContext fd, size_t key, size_t value) {
		return -IOStatus.notImplemented;
	}

	override IOStatus accept(in NodeContext fd, out NodeContext client) {
		return -IOStatus.isNotSocket;
	}

private:
	ubyte[] _data;

	Ref!DirectoryEntryList _entries;
}

class TarFS : FileSystem {
public:
	this(ubyte[] data) {
		_data = data;
		_nodes = kernelAllocator.makeRef!NodeList(kernelAllocator);
		(*_nodes).put(cast(Ref!VNode)kernelAllocator.makeRef!TarRootNode(this, _idCounter, _idCounter));
		_idCounter++;

		_loadTar();
	}

	~this() {
		//TODO: mark pages as free
	}

	override Ref!VNode getNode(size_t id) {
		return (*_nodes)[id];
	}

	override @property Ref!VNode root() {
		return (*_nodes)[0];
	}

	override @property string name() const {
		return "TarFS";
	}

private:
	ubyte[] _data;

	alias NodeList = Vector!(Ref!VNode);
	Ref!NodeList _nodes;
	size_t _idCounter;

	void _loadTar() {
		VirtAddress start = VirtAddress(_data.ptr);
		VirtAddress end = start + _data.length;
		VirtAddress curLoc = start;
		Ref!VNode root = (*_nodes)[0];
		bool isEnd = false;

		PaxHeader paxHeader;
		outer: while (curLoc <= end) {
			TarHeader* header = curLoc.ptr!TarHeader;

			// If it starts with a NULL it is probably empty aka end of the tar file
			if (*curLoc.ptr!ubyte == 0) {
				bool empty = true;
				foreach (ubyte b; curLoc.ptr!ubyte[0 .. _tarHeaderSize])
					if (b) {
						empty = false;
						break;
					}

				if (empty) {
					if (!isEnd) {
						isEnd = true;

						curLoc += (_tarHeaderSize + 511) & ~511;
						continue outer;
					}
					// End of tar file, got two null entries
					break outer;
				}
			}

			// Checksum needs to be valid
			if (!header.checksumValid) {
				log.warning("Invalid tar entry header!: ", (curLoc - start));
				break;
			}

			ssize_t size = paxHeader.fileSize ? paxHeader.fileSize : header.size.toNumber;

			switch (header.typeFlag) with (TarHeader.TypeFlag) {
			case paxExtendedHeader:
				// Parse the file size if not already defined by paxGlobalExtendedHeader
				if (paxHeader.fileSize)
					break;
				goto case;

			case paxGlobalExtendedHeader:
				// Parse for 'size'
				// Format: <size> <name>=<value>\n

				paxHeader = PaxHeader();

				char[] pax = (curLoc + _tarHeaderSize).ptr!char[0 .. header.size.toNumber];
				while (pax.length) {
					char[] line = pax[0 .. pax.indexOf('\n')];

					//ssize_t lineLength = line[0 .. line.indexOf(' ')].toNumber;
					//TODO: use lineLength to validate input
					ssize_t space = line.indexOf(' ');

					size_t eq = line.indexOf('=');

					const char[] key = line[space + 1 .. eq];
					const char[] value = line[eq + 1 .. $];

					if (key == "size") {
						paxHeader.fileSize = value.toNumber;
						break;
					}
					//TODO: Add more parsing of more keys

					pax = pax[line.length + 1 .. $];
				}
				break;

			default:
				Ref!VNode parent = root;
				string name = header.name.fromStringz;
				if (name[$ - 1] == '/')
					name = name[0 .. $ - 1];

				size_t idx = name.indexOfLast('/');

				if (idx != -1) {
					parent = parent.findNode(name[0 .. idx]);
					if (!parent) {
						log.error("Parent: ", name[0 .. idx], " not found! Dropping file!");
						break;
					}
					name = name[idx + 1 .. $];
				}

				if (!name.length || name == ".")
					break;

				(*parent).link(name, (*_nodes).put(cast(Ref!VNode)kernelAllocator.makeRef!TarVNode(this, _idCounter,
						(*parent).id, header, &paxHeader)));
				_idCounter++;
				break;
			}

			isEnd = false;
			curLoc += (_tarHeaderSize + header.size.toNumber + 511) & ~511;
		}
	}

	Ref!VNode _mount(FSNodeID parent, Ref!FileSystem fs) {
		import fs.mountnode : MountVNode;

		return (*_nodes).put(cast(Ref!VNode)kernelAllocator.makeRef!MountVNode(this, _idCounter++, parent, fs));
	}

	void _umount(Ref!VNode toRemove) {
		foreach (idx, node; (*_nodes))
			if (node == toRemove) {
				(*_nodes).remove(idx);
				return;
			}
	}
}
