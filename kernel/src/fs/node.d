module fs.node;

import data.bitfield;
import data.range;
import memory.ref_;

alias FSNodeID = ulong;

/// This represents a FileSystem
/// For example ext2, btrfs, fat, etc.
/// This should contain stuff that is needed to be able to read and write data to the FileSystem
/// Using VNodes ofc
abstract class FileSystem { //TODO: make into a interface?
public:
	abstract Ref!VNode getNode(size_t id);

	abstract @property Ref!VNode root();
	abstract @property string name() const;
}

enum NodeType {
	file,
	directory,
	fifo,
	socket,
	symlink //TODO: Add hardlink? Worth it?
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

	notFound
}

///
enum FileDescriptorMode {
	read = 1 << 0,
	write = 1 << 1,
	append = 1 << 2,
	create = 1 << 3,
	direct = 1 << 4, /// Don't cache or try and speed up anything. Reads and writes will only happen when the calls are made
	fifo = 1 << 5,
}

struct NodeContext { // TODO: Add array of in the process
	uint offset;
}

ushort makeMode(ubyte user, ubyte group, ubyte other) {
	return (user & 0x3) << 6 | (group & 0x3) << 3 | (other & 0x3);
}

abstract class VNode {
public:
	NodeType type;
	FileSystem fs;
	VNode parent;
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
	Ref!FileSystem mounted; /// What is mounted on this node
	//ulong refCounter; // Count for each DirectoryEntry //TODO: Re-add if hardlink are added back

	// No context needed (mostly used for folders)
	abstract IOStatus chmod(ushort mode);
	abstract IOStatus chown(long uid, long gid);

	abstract IOStatus link(in string name, FSNodeID id); // Only used internally for now, aka add a node to a directory
	abstract IOStatus unlink(in string name);

	abstract IOStatus readLink(out string path) const; // Called on the VNode that is the symlink

	abstract IOStatus mount(in string name, Ref!FileSystem filesystem);
	abstract IOStatus umount(in string name);

	// Context related
	abstract IOStatus open(out NodeContext fd, FileDescriptorMode mode);
	abstract IOStatus close(in NodeContext fd);

	abstract IOStatus read(ref NodeContext fd, out ubyte[] buffer, size_t offset) const;
	abstract IOStatus write(ref NodeContext fd, in ubyte[] buffer, size_t offset);

	abstract IOStatus dup(in NodeContext fd, out NodeContext copy) const;

	abstract IOStatus dirEntries(out Ref!DirectoryEntryRange entriesRange);

	abstract IOStatus mkdir(in string name, ushort mode);
	abstract IOStatus rmdir(in string name);

	abstract IOStatus ioctl(in NodeContext fd, size_t key, size_t value);

	abstract IOStatus accept(in NodeContext fd, out NodeContext client) const;
}

struct DirectoryEntry {
	FSNodeID id;
	string name;
}

interface DirectoryEntryRange : InputRange!DirectoryEntry {
}
