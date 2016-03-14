module IO.FS.MountPointNode;

import IO.FS;

class MountPointNode : DirectoryNode {
public:
	this(DirectoryNode oldNode, FSRoot mount) {
		super(oldNode.Permission);
		this.oldNode = oldNode;
		this.mount = mount;
		this.name = oldNode.Name;
	}

	override Node FindNode(string path) {
		return mount.Root.FindNode(path);
	}

	@property override Node[] Nodes() {
		return mount.Root.Nodes;
	}

	@property DirectoryNode OldNode() {
		return oldNode;
	}

protected:
	DirectoryNode oldNode;
	FSRoot mount;

	override Node add(Node node) {
		node.Root = mount;
		return mount.Root.Add(node);
	}

	override Node remove(Node node) {
		node.Root = oldNode.Root;
		return mount.Root.Remove(node);
	}
}
