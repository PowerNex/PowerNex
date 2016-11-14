module io.fs.node;

import io.fs;

import data.bitfield;
import io.log;

abstract class Node {
public:
	this(NodePermissions _permission) {
		_root = null;
		_id = ulong.max;
		_name = "";
		_permission = _permission;
		_parent = null;
	}

	@property FSRoot root() {
		return _root;
	}

	@property FSRoot root(FSRoot root) {
		if (_root == root)
			return _root;
		if (_root)
			_root.remove(this);

		if (root)
			root.add(this);
		_root = root;
		return _root;
	}

	@property ref ulong id() {
		return _id;
	}

	@property ref string name() {
		return _name;
	}

	@property ref NodePermissions permission() {
		return _permission;
	}

	@property DirectoryNode parent() {
		return _parent;
	}

	@property DirectoryNode parent(DirectoryNode parent) {
		if (_parent == parent)
			return _parent;
		if (_parent)
			_parent.remove(this);

		if (parent)
			parent.add(this);
		_parent = parent;
		return _parent;
	}

	override string toString() const {
		return _name;
	}

protected:
	FSRoot _root;
	ulong _id;
	string _name;
	NodePermissions _permission;
	DirectoryNode _parent;
}
