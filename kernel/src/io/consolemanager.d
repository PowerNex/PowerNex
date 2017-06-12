module io.consolemanager;

import kmain : rootFS;
import fs;
import fs.iofs.stdionode;
import memory.ptr;

static struct ConsoleManager {
public static:
	void init() {
		stdout = cast(SharedPtr!StdIONode)(*rootFS).root.findNode("/io/stdio");
	}

	void addKeyboardInput(dchar ch, bool ctrl, bool alt, bool shift) {
		(*stdout).addKeyboardInput(ch);
	}

private static __gshared:
	size_t _active;
	SharedPtr!StdIONode stdout;
}
