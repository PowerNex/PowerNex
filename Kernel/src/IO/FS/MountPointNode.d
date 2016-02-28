module IO.FS.MountPointNode;

import IO.FS;

abstract class MountPointNode : DirectoryNode {
public:
	this(NodePermissions permission, FSRoot mount, DirectoryNode oldNode) {
		super(permission);
		this.mount = mount;
		this.oldNode = oldNode;
	}

	override Node FindNode(string path) {
		return mount.Root.FindNode(path);
	}

	override Node Add(Node node) {
		node.Root = mount;
		node.Parent = mount.Root;
		return node;
	}

	override void Remove(Node node) {
		node.Root = root;
		node.Parent = null;
	}

protected:
	FSRoot mount;
	DirectoryNode oldNode;
}
