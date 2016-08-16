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

	ulong Read(T)(T[] arr, ulong offset) {
		ulong result = Read((cast(ubyte*)arr.ptr)[0 .. T.sizeof * arr.length], offset);
		assert(result == T.sizeof);
		return result;
	}

	ulong Write(T)(T[] obj, ulong offset) {
		ulong result = Write((cast(ubyte*)arr.ptr)[0 .. T.sizeof * arr.length], offset);
		assert(result == T.sizeof);
		return result;
	}

	ulong Read(T)(T* obj, ulong offset) {
		ulong result = Read((cast(ubyte*)obj)[0 .. T.sizeof], offset);
		assert(result == T.sizeof);
		return result;
	}

	ulong Write(T)(T* obj, ulong offset) {
		ulong result = Write((cast(ubyte*)obj)[0 .. T.sizeof], offset);
		assert(result == T.sizeof);
		return result;
	}

	@property ulong Size() {
		return size;
	}

private:
	ulong size;
}
