module io.fs.filenode;

import io.fs;
import io.log;

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
