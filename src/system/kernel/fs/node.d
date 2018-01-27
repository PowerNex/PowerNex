module fs.node;

import stl.bitfield;
import stl.range;
import memory.ptr;

alias FSNodeID = ulong;

/// This represents a FileSystem
/// For example ext2, btrfs, fat, etc.
/// This should contain stuff that is needed to be able to read and write data to the FileSystem
/// Using VNodes ofc
abstract class FileSystem { //TODO: make into a interface?
public:
	abstract SharedPtr!VNode getNode(FSNodeID id);

	abstract @property SharedPtr!VNode root();
	abstract @property string name() const;
}

enum NodeType {
	file,
	directory,
	fifo,
	socket,
	symlink,
	hardlink,
	chardevice, // For example a TTY
	blockdevice // HDD
}

//TODO: fill in errors from the posix standard
/**
 * Negative = error, Positive = Success.
 * To return a error do:
 * --------------------
 * return IOStatus.success; // or
 * return -IOStatus.unknownError; // Everything except the success needs to have a minus '-' before it.
 * --------------------
 */
enum IOStatus : ssize_t {
	success = 0,
	unknownError,
	notImplemented,
	isNotFile,
	isNotDirectory,
	isNotFIFO,
	isNotSocket,
	isNotSymlink,
	isNotHardlink,
	isNotCharDevice,
	isNotBlockDevice,

	notFound,
	wrongFileSystem
}

///
enum FileDescriptorMode {
	read = 1 << 0,
	write = 1 << 1,
	append = 1 << 2,
	create = 1 << 3,
	direct = 1 << 4, /// Don't cache or try and speed up anything. Reads and writes will only happen when the calls are made
	binary = 1 << 5
}

struct NodeContext { // TODO: Add array of in the process
	VNode node; //TODO: refCounter later
	size_t offset;

	IOStatus close() {
		return node.close(this);
	}

	IOStatus read(ubyte[] buffer) {
		return node.read(this, buffer);
	}

	IOStatus write(in ubyte[] buffer) {
		return node.write(this, buffer);
	}

	IOStatus duplicate(out NodeContext copy) {
		return node.duplicate(this, copy);
	}

	IOStatus ioctl(size_t key, size_t value) {
		return node.ioctl(this, key, value);
	}

	IOStatus accept(out NodeContext client) {
		return node.accept(this, client);
	}
}

ushort makeMode(ubyte user, ubyte group, ubyte other) {
	return (user & 0x3) << 6 | (group & 0x3) << 3 | (other & 0x3);
}

abstract class VNode {
public:
	FSNodeID id;
	NodeType type;
	FileSystem fs;
	// Attributes
	ushort mode; // 110 110 100 - RW/RW/R
	long uid; // Negative values are kernel space users, postives are for userspaces users.
	long gid; // Same as above
	ulong size;

	ulong atime; // Update when accessed, TODO: is needed?
	ulong mtime; // Update when content is changed
	ulong ctime; // Update when attributes are changed

	// Internal stuff
	string name; // IsNeeded? Could be used for faster lookups of names
	//__	VNode parent;
	SharedPtr!FileSystem mounted; /// What is mounted on this node
	ulong refCounter; // Count for each DirectoryEntry

	// No context needed (mostly used for folders)
	abstract IOStatus chmod(ushort mode);
	abstract IOStatus chown(long uid, long gid);

	abstract IOStatus link(in string name, SharedPtr!VNode node); // Only used internally for now, aka add a node to a directory
	abstract IOStatus unlink(in string name);

	abstract IOStatus readLink(out string path); // Called on the VNode that is the symlink

	abstract IOStatus mount(in string name, SharedPtr!FileSystem filesystem);
	abstract IOStatus umount(in string name);

	// Context related
	abstract IOStatus open(out NodeContext fd, FileDescriptorMode mode);
	abstract IOStatus close(in NodeContext fd);

	abstract IOStatus read(ref NodeContext fd, ubyte[] buffer);
	abstract IOStatus write(ref NodeContext fd, in ubyte[] buffer);

	abstract IOStatus duplicate(ref NodeContext fd, out NodeContext copy);

	abstract IOStatus dirEntries(out SharedPtr!DirectoryEntryRange entriesRange);

	abstract IOStatus mkdir(in string name, ushort mode);
	abstract IOStatus rmdir(in string name);

	abstract IOStatus ioctl(in NodeContext fd, size_t key, size_t value);

	abstract IOStatus accept(in NodeContext fd, out NodeContext client);
}

struct DirectoryEntry {
	FileSystem fileSystem;
	FSNodeID id;
	char[] name; //TODO: change back to string

	@disable this();

	this(this) {
		import memory.allocator : kernelAllocator, dupArray;

		name = kernelAllocator.dupArray(name);
	}

	this(FileSystem fileSystem, FSNodeID id, char[] name) {
		import memory.allocator : kernelAllocator, dupArray;

		this.fileSystem = fileSystem;
		this.id = id;
		this.name = kernelAllocator.dupArray(name);
	}

	this(FileSystem fileSystem, FSNodeID id, string name) {
		import memory.allocator : kernelAllocator, dupArray;

		this.fileSystem = fileSystem;
		this.id = id;
		this.name = kernelAllocator.dupArray(name);
	}

	this(DirectoryEntry other) {
		import memory.allocator : kernelAllocator, dupArray;

		fileSystem = other.fileSystem;
		id = other.id;
		name = kernelAllocator.dupArray(other.name);
	}

	~this() {
		import memory.allocator : kernelAllocator, dispose;

		if (!name)
			return;
		kernelAllocator.dispose(cast(char[])name);
		name = null;
	}

	void opAssign(DirectoryEntry other) {
		import memory.allocator : kernelAllocator, dupArray;

		fileSystem = other.fileSystem;
		id = other.id;
		name = kernelAllocator.dupArray(other.name);
	}
}

interface DirectoryEntryRange : InputRange!DirectoryEntry {
}

//TODO: (Re)move?
static import data.container;

alias DirectoryEntryList = data.container.Vector!DirectoryEntry;
final class DefaultDirectoryEntryRange : DirectoryEntryRange {
public:
	this(SharedPtr!DirectoryEntryList list) {
		_list = list;
	}

	@property override ref const(DirectoryEntry) front() const {
		return *cast(const(DirectoryEntry)*)&(*_list)[_index];
	}

	@property override ref DirectoryEntry front() {
		return (*_list)[_index];
	}

	override DirectoryEntry moveFront() {
		assert(0, "moveFront not implemented!");
	}

	override void popFront() {
		_index++;
	}

	@property override bool empty() const {
		return _index >= (*_list).length;
	}

	override int opApply(scope int delegate(const DirectoryEntry) cb) const {
		int res;
		for (size_t i = _index; i < (*_list).length; i++) {
			res = cb((*_list)[i]);
			if (res)
				break;
		}
		return res;
	}

	override int opApply(scope int delegate(size_t, const DirectoryEntry) cb) const {
		int res;
		size_t j;
		for (size_t i = _index; i < (*_list).length; i++) {
			res = cb(j++, (*_list)[i]);
			if (res)
				break;
		}
		return res;
	}

	override int opApply(scope int delegate(ref DirectoryEntry) cb) {
		int res;
		for (size_t i = _index; i < (*_list).length; i++) {
			res = cb((*_list)[i]);
			if (res)
				break;
		}
		return res;
	}

	override int opApply(scope int delegate(size_t, ref DirectoryEntry) cb) {
		int res;
		size_t j;
		for (size_t i = _index; i < (*_list).length; i++) {
			res = cb(j++, (*_list)[i]);
			if (res)
				break;
		}
		return res;
	}

private:
	SharedPtr!DirectoryEntryList _list;
	size_t _index;
}
