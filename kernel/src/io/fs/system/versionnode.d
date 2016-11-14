module IO.FS.System.VersionNode;

import IO.FS;
import IO.FS.System;
import Data.String;

immutable uint major = __VERSION__ / 1000;
immutable uint minor = __VERSION__ % 1000;

class VersionNode : FileNode {
public:
	this() {
		super(NodePermissions.DefaultPermissions, 0);
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		char[16] majorBuf;
		char[16] minorBuf;

		string data = "Compiled using '" ~ __VENDOR__ ~ "' D version " ~ itoa(major, majorBuf) ~ "." ~ itoa(minor, minorBuf) ~ "\n";

		if (offset >= data.length)
			return 0;
		ulong size = buffer.length;
		ulong end = size + offset;
		if (end > data.length) {
			end = data.length;
			size = end - offset;
		}

		memcpy(buffer.ptr, &data[offset], size);

		data.destroy;
		return size;
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
