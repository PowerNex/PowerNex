module IO.FS.System.RootNode;

import IO.FS;
import IO.FS.System;

class SystemRootNode : DirectoryNode {
public:
	this() {
		super(0, "System", NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL), parent);

		initNodes();
	}

	override Node GetNode(ulong id) {
		if (id < childrenCount)
			return Entries[children[id]];
		return null;
	}

	override Node GetNode(string name) {
		foreach (id; Children) {
			auto entry = Entries[id];
			if (entry.Name == name)
				return entry;
		}
		return null;
	}

	@property Node[] Entries() {
		return entries[0 .. count];
	}

private:
	Node[] entries;
	ulong count;
	Node add(Node node) {
		if (entries.length == count)
			entries.length += 5;

		node.ID = count;
		entries[count++] = node;
		return node;
	}

	DirectoryNode getOrAdd(DirectoryNode cur, string dir) {
		if (auto node = cur.GetNode(dir))
			return cast(DirectoryNode)node;

		auto node = new SystemDirectoryNode(this, count, dir, cur);
		cur.AddChild(add(node).ID);
		return node;
	}

	void addAt(string path, Node node) {
		//TODO: find folder

		auto parent = this;

		node.Parent = parent;
		add(node);
		parent.AddChild(node.ID);
	}

	void initNodes() {
		addAt("", new VersionNode(this));
	}
}
