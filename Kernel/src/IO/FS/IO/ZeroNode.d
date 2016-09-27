module IO.FS.IO.ZeroNode;

import IO.FS;
import IO.FS.IO;

class ZeroNode : FileNode {
public:
	this() {
		super(NodePermissions.DefaultPermissions, 0);
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		return 0;
	}

	override ulong Write(ubyte[] buffer, ulong offset) {
		return -1;
	}

	override bool Open() {
		return true;
	}

	override void Close() {
	}

private:
}
