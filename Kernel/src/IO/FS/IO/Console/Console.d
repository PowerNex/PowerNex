module IO.FS.IO.Console.Console;

import IO.FS;
import IO.FS.IO.Console;

abstract class Console : FileNode {
public:
	this() {
		super(NodePermissions.DefaultPermissions, 0);
	}
}
