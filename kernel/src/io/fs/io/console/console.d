module io.fs.io.console.console;

import io.fs;
import io.fs.io.console;

abstract class Console : FileNode {
public:
	this() {
		super(NodePermissions.defaultPermissions, 0);
	}
}
