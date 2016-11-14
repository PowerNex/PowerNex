module io.fs.system.fsroot;

import io.fs;
import io.fs.system;

class SystemFSRoot : FSRoot {
public:
	this() {
		auto root = new DirectoryNode(NodePermissions.defaultPermissions);
		root.name = "system";
		root.id = _idCounter++;
		super(root);

		addAt("/version", new VersionNode());
	}
}
