module io.fs.filenode;

import io.fs;
import io.log;

abstract class FileNode : Node {
public:
	this(NodePermissions permission, ulong size) {
		super(permission);
		_size = size;
	}

	abstract bool open();
	abstract void close();
	abstract ulong read(ubyte[] buffer, ulong offset);
	abstract ulong write(ubyte[] buffer, ulong offset);

	ulong read(T)(T[] arr, ulong offset) {
		ulong result = read((cast(ubyte*)arr.ptr)[0 .. T.sizeof * arr.length], offset);
		return result;
	}

	ulong write(T)(T[] obj, ulong offset) {
		ulong result = write((cast(ubyte*)arr.ptr)[0 .. T.sizeof * arr.length], offset);
		return result;
	}

	ulong read(T)(T* obj, ulong offset) {
		ulong result = read((cast(ubyte*)obj)[0 .. T.sizeof], offset);
		assert(result == T.sizeof);
		return result;
	}

	ulong write(T)(T* obj, ulong offset) {
		ulong result = write((cast(ubyte*)obj)[0 .. T.sizeof], offset);
		assert(result == T.sizeof);
		return result;
	}

	ulong read(T)(ref T obj, ulong offset) {
		return read(&obj, offset);
	}

	ulong write(T)(ref T obj, ulong offset) {
		return write(&obj, offset);
	}

	@property ulong size() {
		return _size;
	}

private:
	ulong _size;
}
