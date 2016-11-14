module io.fs.directorynode;

import io.fs;
import io.log;

class DirectoryNode : Node {
public:
	this(NodePermissions permission) {
		super(permission);
	}

	Node findNode(string path) {
		return findNode(path, true);
	}

	MountPointNode mount(DirectoryNode node, FSRoot fs) {
		if (node.parent != this) {
			log.error("Tried to run Mount on ", node.name, " but it doesn't belong to ", name, "! Redirecting");
			node.parent.mount(node, fs);
		}
		MountPointNode mount = new MountPointNode(node, fs);
		node.parent = null;
		node.root = null;
		mount.root = _root;
		mount.parent = this;
		mount.rootMount.parent = this;
		return mount;
	}

	DirectoryNode unmount(MountPointNode node) {
		if (node.parent != this) {
			log.error("Tried to run Unmount on ", node.name, " but it doesn't belong to ", name, "! Redirecting");
			node.parent.unmount(node);
		}
		node.rootMount.parent = null;
		node.parent = null;
		node.root = null;
		DirectoryNode dir = node.oldNode;
		dir.root = _root;
		dir.parent = this;
		node.destroy;
		return dir;
	}

	@property Node[] nodes() {
		return _nodes[0 .. _nodeCount];
	}

	DirectoryNode setParentNoUpdate(DirectoryNode node) {
		if (!node)
			_parent = _oldParent;
		else {
			_oldParent = _parent;
			_parent = node;
		}
		return _parent;
	}

package:
	Node add(Node node) {
		return _add(node);
	}

	Node remove(Node node) {
		return _remove(node);
	}

	Node findNode(string path, bool firstTime) {
		import kmain : rootFS;

		log.info("CUR: ", name, " FindNode: ", path, " firstTime: ", firstTime);
		if (!path.length)
			return this;

		if (path[0] == '/') {
			if (firstTime)
				return rootFS.root.findNode(path[1 .. $], false); //root.root.findNode(path[1 .. $], false);

			while (path.length && path[0] == '/')
				path = path[1 .. $];
			if (!path.length)
				return this;
		}

		if (path.length > 1 && path[0 .. 2] == "..") {
			DirectoryNode p = parent;
			if (!p)
				p = root.root;
			return p.findNode(path[2 .. $], false);
		} else if (path.length > 1 && path[0 .. 2] == "./")
			path = path[2 .. $];

		if (!path.length || path.length == 1 && path[0] == '.')
			return this;

		ulong end = 0;

		while (end < path.length && path[end] != '/')
			end++;

		foreach (node; _nodes[0 .. _nodeCount]) {
			log.info("\t cur Name: ", node.name);
			if (node.name == path[0 .. end]) {
				auto n = node;
				while (true) {
					if (auto hardlink = cast(HardLinkNode)n)
						n = hardlink.target;
					else if (auto softlink = cast(SoftLinkNode)n)
						n = softlink.target;
					else
						break;
				}

				if (end == path.length)
					return n;

				if (auto mp = cast(MountPointNode)node)
					return mp.rootMount.root.findNode(path[end + 1 .. $], false);
				if (auto dir = cast(DirectoryNode)node)
					return dir.findNode(path[end + 1 .. $], false);

				return null;
			}
		}

		return null;
	}

protected:
	DirectoryNode _oldParent;
	Node[] _nodes;
	ulong _nodeCount;

	Node _add(Node node) {
		if (node.parent == this)
			return node;
		log.info("DirectoryNode ", id, " Add: ", node.id, "(", cast(void*)node, ")");
		if (_nodes.length == _nodeCount) {
			_nodes.length += 8;
			for (ulong i = _nodeCount; i < _nodes.length; i++)
				_nodes[i] = null;
		}

		_nodes[_nodeCount++] = node;
		return node;
	}

	Node _remove(Node node) {
		if (node.parent != this)
			return node;
		log.info("DirectoryNode ", id, " Remove: ", node.id, "(", cast(void*)node, ")");
		ulong i = 0;
		while (i < _nodeCount && _nodes[i] != node)
			i++;
		if (i >= _nodeCount)
			return node;

		for (; i < _nodeCount; i++)
			_nodes[i] = _nodes[i + 1];
		_nodeCount--;
		return node;
	}
}
