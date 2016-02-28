module IO.FS.Initrd.FileNode;

import IO.FS.Initrd;
import IO.FS;

final class InitrdFileNode : FileNode {
public:
	this(ubyte* offset, ulong size) {
		this.root = root;
		this.data = offset[0 .. size];
		super(NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL), size);
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		if (offset > data.length)
			return 0;
		ulong size = buffer.length;
		ulong end = size + offset;
		if (end > data.length) {
			end = data.length;
			size = end - offset;
		}

		memcpy(buffer.ptr, &data[offset], size);

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
	ubyte[] data;
}
