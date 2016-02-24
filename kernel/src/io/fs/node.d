module io.fs.node;

import io.fs;

import data.bitfield;
import io.log;

abstract class Node {
public:
	this(ulong id, string name, NodePermissions permission, ulong size, DirectoryNode parent) {
		this.id = id;
		this.name = name;
		this.permission = permission;
		this.size = size;
		this.parent = parent;
	}

	abstract ulong Read(ubyte[] buffer, ulong offset);
	abstract ulong Write(ubyte[] buffer, ulong offset);
	abstract void Open();
	abstract void Close();
	abstract DirRange NodeList();
	abstract Node GetNode(ulong id);
	abstract Node GetNode(string name);

	@property ulong ID() {
		return id;
	}

	@property string Name() {
		return name;
	}

	@property NodePermissions Permission() {
		return permission;
	}

	@property ulong Size() {
		return size;
	}

	@property DirectoryNode Parent() {
		return parent;
	}

	override string toString() const {
		return name;
	}

protected:
	ulong id;
	string name;
	NodePermissions permission;
	ulong size;
	DirectoryNode parent;
}

abstract class MountPointNode : DirectoryNode {
	this(ulong id, string name, NodePermissions permission, ulong size, DirectoryNode parent) {
		super(id, name, permission, size, parent);
	}

protected:
	DirectoryNode root;
	DirectoryNode oldNode;
}
