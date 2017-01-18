module fs.mountnode;

import fs;
import memory.allocator;
import memory.ref_;

final class MountVNode : VNode {
public:
	this(FileSystem fs, FSNodeID id, FSNodeID parent, Ref!FileSystem mount) {
		this.id = id;
		this.type = NodeType.directory;
		this.fs = fs;
		this.mode = makeMode(7, 7, 5);

		this.name = "TarFS";

		this.mounted = mount;
		_parent = parent;
		_root = mount.root;
	}

	// No context needed (mostly used for folders)
	override IOStatus chmod(ushort mode) {
		this.mode = mode;
		return IOStatus.success;
	}

	override IOStatus chown(long uid, long gid) {
		this.uid = uid;
		this.gid = gid;
		return IOStatus.success;
	}

	override IOStatus link(in string name, Ref!VNode node) { // Only used internally for now, aka add a node to a director
		if (node.fs != mounted)
			return -IOStatus.wrongFileSystem;
		return _root.link(name, node);
	}

	override IOStatus unlink(in string name) {
		return _root.unlink(name);
	}

	override IOStatus readLink(out string path) { // Called on the VNode that is the symlink
		return _root.readLink(path);
	}

	override IOStatus mount(in string name, Ref!FileSystem filesystem) {
		return _root.mount(name, filesystem);
	}

	override IOStatus umount(in string name) {
		return _root.umount(name);
	}

	// Context related
	override IOStatus open(out NodeContext fd, FileDescriptorMode mode) {
		return _root.open(fd, mode);
	}

	override IOStatus close(in NodeContext fd) {
		return _root.close(fd);
	}

	override IOStatus read(ref NodeContext fd, ubyte[] buffer) {
		return _root.read(fd, buffer);
	}

	override IOStatus write(ref NodeContext fd, in ubyte[] buffer) {
		return _root.write(fd, buffer);
	}

	override IOStatus duplicate(ref NodeContext fd, out NodeContext copy) {
		return _root.duplicate(fd, copy);
	}

	override IOStatus dirEntries(out Ref!DirectoryEntryRange entriesRange) {
		Ref!DirectoryEntryRange range;
		IOStatus ret = _root.dirEntries(range);

		if (ret != IOStatus.success)
			return ret;

		entriesRange = cast(Ref!DirectoryEntryRange)kernelAllocator.makeRef!MountDirectoryEntryRange(range, fs, _parent);
		return IOStatus.success;
	}

	override IOStatus mkdir(in string name, ushort mode) {
		return _root.mkdir(name, mode);
	}

	override IOStatus rmdir(in string name) {
		return _root.rmdir(name);
	}

	override IOStatus ioctl(in NodeContext fd, size_t key, size_t value) {
		return _root.ioctl(fd, key, value);
	}

	override IOStatus accept(in NodeContext fd, out NodeContext client) {
		return _root.accept(fd, client);
	}

private:
	Ref!VNode _root;
	FSNodeID _parent;
}

final class MountDirectoryEntryRange : DirectoryEntryRange {
public:
	this(Ref!DirectoryEntryRange range, FileSystem fs, FSNodeID parent) {
		_range = range;
		_fs = fs;
		_parent = parent;
		_parentEntry = DirectoryEntry(_fs, _parent, "..");
	}

	@property override const(DirectoryEntry) front() const {
		if (_range.front.name == "..")
			return _parentEntry;

		return _range.front;
	}

	@property override ref DirectoryEntry front() {
		if (_range.front.name == "..")
			return _parentEntry;

		return _range.front;
	}

	override DirectoryEntry moveFront() {
		assert(0, "moveFront not implemented!");
	}

	override void popFront() {
		_range.popFront();
	}

	@property override bool empty() const {
		return _range.empty;
	}

	override int opApply(scope int delegate(const DirectoryEntry) cb) {
		int res;
		while (!empty) {
			res = cb(front());
			if (res)
				break;
			popFront();
		}
		return res;
	}

	override int opApply(scope int delegate(size_t, const DirectoryEntry) cb) {
		int res;
		size_t j;
		while (!empty) {
			res = cb(j++, front());
			if (res)
				break;
			popFront();
		}
		return res;
	}

	override int opApply(scope int delegate(ref DirectoryEntry) cb) {
		int res;
		while (!empty) {
			res = cb(front());
			if (res)
				break;
			popFront();
		}
		return res;
	}

	override int opApply(scope int delegate(size_t, ref DirectoryEntry) cb) {
		int res;
		size_t j;
		while (!empty) {
			res = cb(j++, front());
			if (res)
				break;
			popFront();
		}
		return res;
	}

private:
	Ref!DirectoryEntryRange _range;
	FileSystem _fs;
	FSNodeID _parent;
	DirectoryEntry _parentEntry;
}
