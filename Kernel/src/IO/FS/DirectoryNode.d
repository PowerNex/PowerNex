module IO.FS.DirectoryNode;

import IO.FS;
import IO.Log;

class DirectoryNode : Node {
public:
	this(NodePermissions permission) {
		super(permission);
	}

	Node FindNode(string path) {
		if (path.length < 2) {
			if (path[0 .. 2] == "..")
				return parent.FindNode(path[2 .. $]);
			if (path[0 .. 2] == "./")
				path = path[2 .. $];
		}

		if (path.length == 0)
			return this;

		if (path[0 .. 1] == "/")
			path = path[1 .. $];

		ulong end = 0;

		log.Info("FindNode: ", path);

		while (end < path.length && path[end] != '/')
			end++;

		foreach (node; nodes[0 .. nodeCount]) {
			log.Info("\t cur Name: ", node.Name);
			if (node.Name == path[0 .. end]) {
				auto n = node;
				while (true) {
					if (auto hardlink = cast(HardLinkNode)n)
						n = hardlink.Target;
					else if (auto softlink = cast(SoftLinkNode)n)
						n = softlink.Target;
					else
						break;
				}

				if (end == path.length)
					return n;

				if (auto dir = cast(DirectoryNode)node)
					return dir.FindNode(path[end + 1 .. $]);

				return null;
			}
		}

		return null;
	}

	Node Add(Node node) {
		if (node.Parent == this)
			return node;
		log.Info("DirectoryNode ", ID, " Add: ", node.ID);
		if (nodes.length == nodeCount) {
			nodes.length += 8;
			for (ulong i = nodeCount; i < nodes.length; i++)
				nodes[i] = null;
		}

		nodes[nodeCount++] = node;
		node.Parent = this;
		return node;
	}

	void Remove(Node node) {
		if (node.Parent != this)
			return;
		log.Info("DirectoryNode ", ID, " Remove: ", node.ID);
		ulong i = 0;
		while (i < nodeCount && nodes[i] == node)
			i++;
		if (i >= nodeCount)
			return;

		nodes[i].Parent = root.Root;

		for (; i < nodeCount; i++)
			nodes[i] = nodes[i + 1];
		nodes[i - 1] = null;
		nodeCount--;
	}

	@property Node[] Nodes() {
		return nodes[0 .. nodeCount];
	}

protected:
	Node[] nodes;
	ulong nodeCount;
}
