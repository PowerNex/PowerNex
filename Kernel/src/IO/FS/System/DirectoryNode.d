module IO.FS.System.DirectoryNode;

import IO.FS.System;
import IO.FS;

final class SystemDirectoryNode : DirectoryNode {
	this(SystemRootNode root, ulong id, string name, DirectoryNode parent) {
		this.root = root;
		super(id, name, NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL), parent);
	}

	override Node GetNode(ulong id) {
		if (id < childrenCount)
			return root.Entries[children[id]];
		return null;
	}

	override Node GetNode(string name) {
		foreach (id; Children) {
			auto entry = root.Entries[id];
			if (entry.Name == name)
				return entry;
		}
		return null;
	}

private:
	SystemRootNode root;
}
