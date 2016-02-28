module IO.FS.FileNode;

import IO.FS;
import IO.Log;

abstract class FileNode : Node {
public:
	this(NodePermissions permission, ulong size) {
		super(permission);
		this.size = size;
	}

	abstract void Open();
	abstract void Close();
	abstract ulong Read(ubyte[] buffer, ulong offset);
	abstract ulong Write(ubyte[] buffer, ulong offset);

	@property ulong Size() {
		return size;
	}

private:
	ulong size;
}
