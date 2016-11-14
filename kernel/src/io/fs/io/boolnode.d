module IO.FS.IO.BoolNode;

import IO.FS;
import IO.FS.IO;

class BoolNode : FileNode {
public:
	this(bool val) {
		super(NodePermissions.DefaultPermissions, 0);
		this.val = val;
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		if (buffer.length == 0)
			return 0;
		buffer[1] = val;
		return 1;
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
	bool val;
}
