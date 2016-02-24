module IO.FS.DirectoryNode;

import IO.FS;
import IO.Log;

struct DirRange {
	DirectoryNode node;
	ulong id;

	this(DirectoryNode node) {
		this.node = node;
	}

	@property bool empty() {
		return !node.GetNode(id);
	}

	@property Node front() {
		return node.GetNode(id);
	}

	void popFront() {
		id++;
	}
}

class DirectoryNode : Node {
	this(ulong id, string name, NodePermissions permission, DirectoryNode parent) {
		super(id, name, permission, 0, parent);
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		log.Fatal("Can't use Read(ubyte[], ulong) on a DirectoryNode");
		assert(0);
	}

	override ulong Write(ubyte[] buffer, ulong offset) {
		log.Fatal("Can't use Write(ubyte[], ulong) on a DirectoryNode");
		assert(0);
	}

	override void Open() {
		log.Fatal("Can't use Open() on a DirectoryNode");
		assert(0);
	}

	override void Close() {
		log.Fatal("Can't use Close() on a DirectoryNode");
		assert(0);
	}

	override DirRange NodeList() {
		return DirRange(this);
	}

	void AddChild(ulong child) {
		if (childrenCount == children.length)
			children.length += 5;
		children[childrenCount++] = child;
	}

	@property ulong[] Children() {
		return children[0 .. childrenCount];
	}

protected:
	ulong[] children;
	ulong childrenCount;
}
