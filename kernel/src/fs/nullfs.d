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
		_entries.put(DirectoryEntry(id, "."));
		_entries.put(DirectoryEntry(parent, ".."));
		_entries.put(DirectoryEntry(id, "This is a NullFS!"));
		_entries.put(DirectoryEntry(id, "If you see this it probably mean"));
		_entries.put(DirectoryEntry(id, "that you encountered a bug!"));
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

	override IOStatus link(in string name, FSNodeID id) {
		_entries.put(DirectoryEntry(id, name.dup));
		return IOStatus.success;
	}

	override IOStatus unlink(in string name) {
		foreach (DirectoryEntry e; _entries.data)
			if (e.name == name) {
				_entries.remove(e.id);
				return IOStatus.success;
			}
		return -IOStatus.notFound;
	}

	override IOStatus readLink(out string path) const {
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

	override IOStatus read(ref NodeContext fd, out ubyte[] buffer, size_t offset) const {
		return -IOStatus.isNotFile;
	}

	override IOStatus write(ref NodeContext fd, in ubyte[] buffer, size_t offset) {
		return -IOStatus.isNotFile;
	}

	override IOStatus dup(in NodeContext fd, out NodeContext copy) const {
		return -IOStatus.isNotFile;
	}

	override IOStatus dirEntries(out Ref!DirectoryEntryRange entriesRange) {
		entriesRange = cast(Ref!DirectoryEntryRange)kernelAllocator.makeRef!Range(_entries);
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

	override IOStatus accept(in NodeContext fd, out NodeContext client) const {
		return -IOStatus.isNotSocket;
	}

private:
	alias DirectoryEntryList = Vector!DirectoryEntry;

	Ref!DirectoryEntryList _entries;

	final class Range : DirectoryEntryRange {
	public:
		this(Ref!DirectoryEntryList list) {
			_list = list;
		}

		@property override DirectoryEntry front() {
			return _list[_index];
		}

		override DirectoryEntry moveFront() {
			assert(0, "moveFront not implemented!");
		}

		override void popFront() {
			_index++;
		}

		@property override bool empty() const {
			return _index >= _list.length;
		}

		override int opApply(scope int delegate(const DirectoryEntry) cb) const {
			int res;
			for (size_t i = _index; i < _list.length; i++) {
				res = cb(_list[i]);
				if (res)
					break;
			}
			return res;
		}

		override int opApply(scope int delegate(size_t, const DirectoryEntry) cb) const {
			int res;
			size_t j;
			for (size_t i = _index; i < _list.length; i++) {
				res = cb(j++, _list[i]);
				if (res)
					break;
			}
			return res;
		}

		override int opApply(scope int delegate(ref DirectoryEntry) cb) {
			int res;
			for (size_t i = _index; i < _list.length; i++) {
				res = cb(_list[i]);
				if (res)
					break;
			}
			return res;
		}

		override int opApply(scope int delegate(size_t, ref DirectoryEntry) cb) {
			int res;
			size_t j;
			for (size_t i = _index; i < _list.length; i++) {
				res = cb(j++, _list[i]);
				if (res)
					break;
			}
			return res;
		}

	private:
		Ref!DirectoryEntryList _list;
		size_t _index;
	}
}

class NullFS : FileSystem {
public:
	this() {
		_nodes = kernelAllocator.makeRef!NodeList(kernelAllocator);
		_nodes.put(cast(Ref!VNode)kernelAllocator.makeRef!NullRootNode(this, _idCounter, _idCounter));
		_idCounter++;
	}

	override Ref!VNode getNode(size_t id) {
		return _nodes[id];
	}

	override @property Ref!VNode root() {
		return _nodes[0];
	}

	override @property string name() const {
		return "NullFS";
	}

private:
	alias NodeList = Vector!(Ref!VNode);
	Ref!NodeList _nodes;
	size_t _idCounter;
}
