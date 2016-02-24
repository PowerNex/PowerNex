module IO.FS.Node;

import IO.FS;

import Data.BitField;
import IO.Log;

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

	@property ref ulong ID() {
		return id;
	}

	@property ref string Name() {
		return name;
	}

	@property ref NodePermissions Permission() {
		return permission;
	}

	@property ref ulong Size() {
		return size;
	}

	@property ref DirectoryNode Parent() {
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
	this(ulong id, string name, NodePermissions permission, DirectoryNode parent) {
		super(id, name, permission, parent);
	}

protected:
	DirectoryNode root;
	DirectoryNode oldNode;
}
