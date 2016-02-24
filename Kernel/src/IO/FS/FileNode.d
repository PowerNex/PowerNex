module IO.FS.FileNode;

import IO.FS;
import IO.Log;

abstract class FileNode : Node {
	this(ulong id, string name, NodePermissions permission, ulong size, DirectoryNode parent) {
		super(id, name, permission, size, parent);
	}

	override DirRange NodeList() {
		log.Fatal("Can't use NodeList() on a FileNode");
		assert(0);
	}

	override Node GetNode(ulong id) {
		log.Fatal("Can't use GetNode(ulong) on a FileNode");
		assert(0);
	}

	override Node GetNode(string name) {
		log.Fatal("Can't use GetNode(string) on a FileNode");
		assert(0);
	}
}
