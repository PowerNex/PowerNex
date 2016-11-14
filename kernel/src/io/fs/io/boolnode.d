module io.fs.io.boolnode;

import io.fs;
import io.fs.io;

class BoolNode : FileNode {
public:
	this(bool val) {
		super(NodePermissions.defaultPermissions, 0);
		this._val = _val;
	}

	override ulong read(ubyte[] buffer, ulong offset) {
		if (buffer.length == 0)
			return 0;
		buffer[1] = _val;
		return 1;
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
	bool _val;
}
