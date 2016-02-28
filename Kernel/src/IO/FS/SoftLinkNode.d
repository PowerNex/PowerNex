module IO.FS.SoftLinkNode;

import IO.FS;

class SoftLinkNode : Node {
public:
	this(NodePermissions permission, string path) {
		super(permission);
		this.path = path;
	}

	@property ref string Path() {
		return path;
	}

	@property Node Target() {
		return parent.FindNode(path);
	}

private:
	string path;
}
