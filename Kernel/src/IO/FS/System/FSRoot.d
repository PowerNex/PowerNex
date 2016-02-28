module IO.FS.System.FSRoot;

import IO.FS;
import IO.FS.System;

class SystemFSRoot : FSRoot {
public:
	this(DirectoryNode parent) {
		auto root = new DirectoryNode(NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL));
		root.Name = "System";
		root.ID = idCounter++;
		if (parent)
			parent.Add(root);
		super(root);

		addAt("/version", new VersionNode());
	}
}
