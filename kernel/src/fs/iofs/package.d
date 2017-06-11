module fs.iofs;

import fs;
import data.container;
import memory.allocator;
import memory.ptr;

import fs.iofs.stdionode;

final class IORootNode : VNode {
public:
	this(FileSystem fs, FSNodeID id, FSNodeID parent) {
		this.id = id;
		this.type = NodeType.directory;
		this.fs = fs;
		this.mode = makeMode(7, 7, 5);

		this.name = "IOFS";

		_entries = kernelAllocator.makeSharedPtr!DirectoryEntryList(kernelAllocator);
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

	override IOStatus link(in string name, SharedPtr!VNode node) {
		import memory.allocator : kernelAllocator, dupArray;
		(*_entries).put(DirectoryEntry(fs, (*node).id, kernelAllocator.dupArray(name)));
		return IOStatus.success;
	}

	override IOStatus unlink(in string name) {
		foreach (DirectoryEntry e; *_entries)
			if (e.name == name) {
				(*_entries).remove(e.id);
				return IOStatus.success;
			}
		return -IOStatus.notFound;
	}

	override IOStatus readLink(out string path) {
		return -IOStatus.isNotSymlink;
	}

	override IOStatus mount(in string name, SharedPtr!FileSystem filesystem) {
		return -IOStatus.notImplemented;
	}

	override IOStatus umount(in string name) {
		return -IOStatus.notImplemented;
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

	override IOStatus dirEntries(out SharedPtr!DirectoryEntryRange entriesRange) {
		entriesRange = cast(SharedPtr!DirectoryEntryRange)kernelAllocator.makeSharedPtr!DefaultDirectoryEntryRange(_entries);
		return entriesRange ? IOStatus.success : -IOStatus.unknownError;
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
	SharedPtr!DirectoryEntryList _entries;
}

final class IOFS : FileSystem {
public:
	this() {
		_nodes = kernelAllocator.makeSharedPtr!(Vector!(SharedPtr!VNode))(kernelAllocator);
		SharedPtr!VNode root = (*_nodes).put(cast(SharedPtr!VNode)kernelAllocator.makeSharedPtr!IORootNode(this, _idCounter, _idCounter));
		_idCounter++;
		(*root).link("stdio", (*_nodes).put(cast(SharedPtr!VNode)kernelAllocator.makeSharedPtr!StdIONode(this, _idCounter++, 0)));
	}

	override SharedPtr!VNode getNode(FSNodeID id) {
		return (*_nodes)[id];
	}

	override @property SharedPtr!VNode root() {
		return (*_nodes)[0];
	}

	override @property string name() const {
		return "IOFS";
	}

private:
	SharedPtr!(Vector!(SharedPtr!VNode)) _nodes;
	FSNodeID _idCounter;
}
