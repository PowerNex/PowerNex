module io.consolemanager;

import kmain : rootFS;
import fs;
import fs.iofs.stdionode;
import memory.ptr;

class ConsoleManager {
public:
	void init() {
		stdout = cast(SharedPtr!StdIONode)(*rootFS).root.findNode("/io/stdio");
	}

	void addKeyboardInput(dchar ch, bool ctrl, bool alt, bool shift) {
		(*stdout).addKeyboardInput(ch);
	}

private:
	size_t _active;
	SharedPtr!StdIONode stdout;
}

ConsoleManager getConsoleManager() {
	import data.util : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, ConsoleManager)] data;
	__gshared ConsoleManager cm;

	if (!cm)
		cm = inplaceClass!ConsoleManager(data);
	return cm;
}
