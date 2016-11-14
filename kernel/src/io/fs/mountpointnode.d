module io.fs.mountpointnode;

import io.fs;

class MountPointNode : DirectoryNode {
public:
	this(DirectoryNode oldNode, FSRoot mount) {
		super(oldNode.permission);
		_oldNode = oldNode;
		_mount = mount;
		_name = _oldNode.name;
	}

	override Node findNode(string path) {
		return _mount.root.findNode(path);
	}

	override MountPointNode mount(DirectoryNode node, FSRoot fs) {
		return _mount.root.mount(node, fs);
	}

	override DirectoryNode unmount(MountPointNode node) {
		return _mount.root.unmount(node);
	}

	@property override Node[] nodes() {
		return _mount.root.nodes;
	}

	@property FSRoot rootMount() {
		return _mount;
	}

	@property DirectoryNode oldNode() {
		return _oldNode;
	}

protected:
	DirectoryNode _oldNode;
	FSRoot _mount;

	override Node _add(Node node) {
		node.root = _mount;
		return _mount.root.add(node);
	}

	override Node _remove(Node node) {
		node.root = _oldNode.root;
		return _mount.root.remove(node);
	}
}
