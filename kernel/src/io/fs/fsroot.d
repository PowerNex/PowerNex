module IO.FS.FSRoot;
import IO.FS;
import IO.Log;

abstract class FSRoot {
public:
	this(DirectoryNode root) {
		this.root = root;
		root.Root = this;
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

	@property DirectoryNode Parent() {
		return root.Parent;
	}

	@property DirectoryNode Parent(DirectoryNode parent) {
		return root.SetParentNoUpdate(parent);
	}

package:
	Node Add(Node node) {
		if (node.Root == this)
			return node;
		if (nodes.length == nodeCount)
			nodes.length += 8;

		nodes[nodeCount++] = node;
		node.ID = idCounter++;
		log.Info("FSRoot Add: ", node.ID, "(", cast(void*)node, ")");
		return node;
	}

	Node Remove(Node node) {
		if (node.Root != this)
			return node;
		log.Info("FSRoot Remove: ", node.ID, "(", cast(void*)node, ")");
		ulong i = 0;
		while (i < nodeCount && nodes[i] != node)
			i++;
		if (i >= nodeCount)
			return node;

		for (; i < nodeCount - 1; i++)
			nodes[i] = nodes[i + 1];
		nodeCount--;
		return node;
	}

protected:
	DirectoryNode root;
	Node[] nodes;
	ulong nodeCount;
	ulong idCounter;

	DirectoryNode getOrAdd(DirectoryNode cur, string dir) {
		if (auto node = cur.FindNode(dir))
			return cast(DirectoryNode)node;

		auto node = new DirectoryNode(NodePermissions.DefaultPermissions);
		node.Name = dir;
		node.Root = this;
		node.Parent = cur;
		return node;
	}

	Node addAt(string path, Node node) {
		if (path[0] != '/' || path[$ - 1] == '/')
			return null;
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
		node.Root = this;
		node.Parent = parent;
		return node;
	}
}
