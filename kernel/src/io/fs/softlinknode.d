module io.fs.softlinknode;

import io.fs;

class SoftLinkNode : Node {
public:
	this(NodePermissions permission, string path) {
		super(permission);
		_path = path;
	}

	@property ref string path() {
		return _path;
	}

	@property Node target() {
		return parent.findNode(_path);
	}

private:
	string _path;
}
