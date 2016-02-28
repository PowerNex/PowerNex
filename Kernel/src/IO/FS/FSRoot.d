module IO.FS.FSRoot;
import IO.FS;
import IO.Log;

abstract class FSRoot {
public:
	this(DirectoryNode root) {
		this.root = root;
	}

	Node Add(Node node) {
		if (node.Root == this)
			return node;
		if (nodes.length == nodeCount)
			nodes.length += 8;

		nodes[nodeCount++] = node;
		node.ID = idCounter++;
		log.Info("FSRoot Add: ", node.ID);
		return node;
	}

	void Remove(Node node) {
		if (node.Root != this)
			return;
		log.Info("FSRoot Remove: ", node.ID);
		ulong i = 0;
		while (i < nodeCount && nodes[i] == node)
			i++;
		if (i >= nodeCount)
			return;

		nodes[i].destroy;
		for (; i < nodeCount; i++)
			nodes[i] = nodes[i + 1];
		nodes[i - 1] = null;
		nodeCount--;
	}

	Node[] Nodes() {
		return nodes[0 .. nodeCount];
	}

	Node GetNode(ulong id) {
		foreach (node; nodes[0 .. nodeCount])
			if (node.ID == id)
				return node;
		return null;
	}

	@property ref DirectoryNode Root() {
		return root;
	}

protected:
	DirectoryNode root;
	Node[] nodes;
	ulong nodeCount;
	ulong idCounter;

	DirectoryNode getOrAdd(DirectoryNode cur, string dir) {
		if (auto node = cur.FindNode(dir))
			return cast(DirectoryNode)node;

		auto node = new DirectoryNode(NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL));
		node.Name = dir;
		cur.Add(Add(node));
		return node;
	}

	void addAt(string path, Node node) {
		if (path[0] != '/' || path[$ - 1] == '/')
			return;
		ulong start = 1;
		ulong end = 1;
		DirectoryNode parent = Root;
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

		node.Name = path[start .. $];
		parent.Add(Add(node));
	}
}
