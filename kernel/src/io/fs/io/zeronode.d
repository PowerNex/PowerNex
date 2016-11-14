module io.fs.io.zeronode;

import io.fs;
import io.fs.io;

class ZeroNode : FileNode {
public:
	this() {
		super(NodePermissions.defaultPermissions, 0);
	}

	override ulong read(ubyte[] buffer, ulong offset) {
		return 0;
	}

	override ulong write(ubyte[] buffer, ulong offset) {
		return -1;
	}

	override bool open() {
		return true;
	}

	override void close() {
	}

private:
}
