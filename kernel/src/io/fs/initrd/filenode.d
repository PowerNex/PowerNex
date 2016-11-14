module io.fs.initrd.filenode;

import io.fs.initrd;
import io.fs;

final class InitrdFileNode : FileNode {
public:
	this(ubyte* offset, ulong size) {
		root = root;
		_data = offset[0 .. size];
		super(NodePermissions.defaultPermissions, size);
	}

	override ulong read(ubyte[] buffer, ulong offset) {
		if (offset >= _data.length)
			return 0;
		ulong size = buffer.length;
		ulong end = size + offset;
		if (end > _data.length) {
			end = _data.length;
			long tmp = end - offset;
			size = (tmp < 0) ? 0 : tmp;
		}

		memcpy(buffer.ptr, &_data[offset], size);

		return size;
	}

	override ulong write(ubyte[] buffer, ulong offset) {
		return -1;
	}

	override bool open() {
		return true;
	}

	override void close() {
	}

	@property ubyte[] rawAccess() {
		return _data;
	}

private:
	ubyte[] _data;
}
