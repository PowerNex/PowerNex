module io.fs.fsroot;
import io.fs;
import io.log;

abstract class FSRoot {
public:
	this(DirectoryNode root) {
		_root = root;
		_root.root = this;
	}

	Node[] nodes() {
		return _nodes[0 .. _nodeCount];
	}

	Node getNode(ulong id) {
		foreach (node; _nodes[0 .. _nodeCount])
			if (node.id == id)
				return node;
		return null;
	}

	@property ref DirectoryNode root() {
		return _root;
	}

	@property DirectoryNode parent() {
		return _root.parent;
	}

	@property DirectoryNode parent(DirectoryNode parent) {
		return _root.setParentNoUpdate(parent);
	}

package:
	Node add(Node node) {
		if (node.root == this)
			return node;
		if (_nodes.length == _nodeCount)
			_nodes.length += 8;

		_nodes[_nodeCount++] = node;
		node.id = _idCounter++;
		log.info("FSRoot Add: ", node.id, "(", cast(void*)node, ")");
		return node;
	}

	Node remove(Node node) {
		if (node.root != this)
			return node;
		log.info("FSRoot Remove: ", node.id, "(", cast(void*)node, ")");
		ulong i = 0;
		while (i < _nodeCount && _nodes[i] != node)
			i++;
		if (i >= _nodeCount)
			return node;

		for (; i < _nodeCount - 1; i++)
			_nodes[i] = _nodes[i + 1];
		_nodeCount--;
		return node;
	}

protected:
	DirectoryNode _root;
	Node[] _nodes;
	ulong _nodeCount;
	ulong _idCounter;

	DirectoryNode getOrAdd(DirectoryNode cur, string dir) {
		if (auto node = cur.findNode(dir))
			return cast(DirectoryNode)node;

		auto node = new DirectoryNode(NodePermissions.defaultPermissions);
		node.name = dir;
		node.root = this;
		node.parent = cur;
		return node;
	}

	Node addAt(string path, Node node) {
		if (path[0] != '/' || path[$ - 1] == '/')
			return null;
		ulong start = 1;
		ulong end = 1;
		DirectoryNode parent = root;
		while (end < path.length) {
			while (end < path.length && path[end] != '/')
				end++;
			if (end >= path.length)
				break;

			// End is on a '/'

			if (start != end)
				parent = getOrAdd(parent, path[start .. end]);
			start = end + 1;
			end++;
		}

		node.name = path[start .. $];
		node.root = this;
		node.parent = parent;
		return node;
	}
}
