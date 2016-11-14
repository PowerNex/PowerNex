module io.fs.system.versionnode;

import io.fs;
import io.fs.system;
import data.string_;

private immutable uint _major = __VERSION__ / 1000;
private immutable uint _minor = __VERSION__ % 1000;

class VersionNode : FileNode {
public:
	this() {
		super(NodePermissions.defaultPermissions, 0);
	}

	override ulong read(ubyte[] buffer, ulong offset) {
		char[16] majorBuf;
		char[16] minorBuf;

		string data = "Compiled using '" ~ __VENDOR__ ~ "' D version " ~ itoa(_major, majorBuf) ~ "." ~ itoa(_minor, minorBuf) ~ "\n";

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
