module fs.nullfs;

import fs;

import data.container;
import memory.ref_;
import memory.allocator;

//TODO: Check if you have permissions to change this stuff EVERYWHERE, Add that to VNode?
final class NullRootNode : VNode {
public:
	this(FileSystem fs, size_t id, size_t parent) {
		this.type = NodeType.directory;
		this.fs = fs;
		this.mode = makeMode(6, 6, 4);

		this.name = "RootFS";

		_entries = makeRef!DirectoryEntryList(kernelAllocator, kernelAllocator);
		(*_entries).put(DirectoryEntry(fs, id, "."));
		(*_entries).put(DirectoryEntry(fs, parent, ".."));
		(*_entries).put(DirectoryEntry(fs, id, "This is a NullFS!"));
		(*_entries).put(DirectoryEntry(fs, id, "If you see this it probably mean"));
		(*_entries).put(DirectoryEntry(fs, id, "that you encountered a bug!"));
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

class NullFS : FileSystem {
public:
	this() {
		_nodes = kernelAllocator.makeRef!NodeList(kernelAllocator);
		(*_nodes).put(cast(Ref!VNode)kernelAllocator.makeRef!NullRootNode(this, _idCounter, _idCounter));
		_idCounter++;
	}

	override Ref!VNode getNode(FSNodeID id) {
		return (*_nodes)[id];
	}

	override @property Ref!VNode root() {
		return (*_nodes)[0];
	}

	override @property string name() const {
		return "NullFS";
	}

private:
	alias NodeList = Vector!(Ref!VNode);
	Ref!NodeList _nodes;
	size_t _idCounter;
}
