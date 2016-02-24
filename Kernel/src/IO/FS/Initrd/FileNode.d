module IO.FS.Initrd.FileNode;

import IO.FS.Initrd;
import IO.FS;

final class InitrdFileNode : FileNode {
public:
	this(InitrdRootNode root, ulong id, string name, ubyte* offset, ulong size, DirectoryNode parent) {
		this.root = root;
		this.data = offset[0 .. size];
		super(id, name, NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL), size, parent);
		this.size = size;
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		ulong size = buffer.length;
		ulong end = size + offset;
		if (end > data.length) {
			end = data.length;
			size = end - offset;
		}

		memcpy(&buffer[offset], data.ptr, size);

		return size;
	}

	override ulong Write(ubyte[] buffer, ulong offset) {
		return -1;
	}

	override void Open() {
	}

	override void Close() {
	}

private:
	InitrdRootNode root;
	ubyte[] data;
}
