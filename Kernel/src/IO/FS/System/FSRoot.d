module IO.FS.System.FSRoot;

import IO.FS;
import IO.FS.System;

class SystemFSRoot : FSRoot {
public:
	this() {
		auto root = new DirectoryNode(NodePermissions.DefaultPermissions);
		root.Name = "System";
		root.ID = idCounter++;
		super(root);

		addAt("/version", new VersionNode());
	}
}
