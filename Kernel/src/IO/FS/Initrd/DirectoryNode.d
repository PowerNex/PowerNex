module IO.FS.Initrd.DirectoryNode;

import IO.FS.Initrd;
import IO.FS;

final class InitrdDirectoryNode : DirectoryNode {
	this(InitrdRootNode root, ulong id, string name, DirectoryNode parent) {
		this.root = root;
		super(id, name, NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL), 0, parent);
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
	InitrdRootNode root;
}
