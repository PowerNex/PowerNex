module IO.FS.Node;

import IO.FS;

import Data.BitField;
import IO.Log;

abstract class Node {
public:
	this(NodePermissions permission) {
		this.root = null;
		this.id = ulong.max;
		this.name = "";
		this.permission = permission;
		this.parent = null;
	}

	@property FSRoot Root() {
		return root;
	}

	@property FSRoot Root(FSRoot root) {
		if (this.root == root)
			return root;
		if (this.root)
			this.root.Remove(this);

		if (root)
			root.Add(this);
		this.root = root;
		return root;
	}

	@property ref ulong ID() {
		return id;
	}

	@property ref string Name() {
		return name;
	}

	@property ref NodePermissions Permission() {
		return permission;
	}

	@property DirectoryNode Parent() {
		return parent;
	}

	@property DirectoryNode Parent(DirectoryNode parent) {
		if (this.parent == parent)
			return parent;
		if (this.parent)
			this.parent.Remove(this);

		if (parent)
			parent.Add(this);
		this.parent = parent;
		return parent;
	}

	override string toString() const {
		return name;
	}

protected:
	FSRoot root;
	ulong id;
	string name;
	NodePermissions permission;
	DirectoryNode parent;
}
