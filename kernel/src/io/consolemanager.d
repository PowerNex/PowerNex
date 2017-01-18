module io.consolemanager;

import kmain : rootFS;
import fs;
import fs.iofs.stdionode;
import memory.ref_;

class ConsoleManager {
public:
	void init() {
		stdout = cast(Ref!StdIONode)rootFS.root.findNode("/io/stdio");
	}

	void addKeyboardInput(dchar ch, bool ctrl, bool alt, bool shift) {
		stdout.addKeyboardInput(ch);
	}

private:
	size_t _active;
	Ref!StdIONode stdout;
}

ConsoleManager getConsoleManager() {
	import data.util : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, ConsoleManager)] data;
	__gshared ConsoleManager cm;

	if (!cm)
		cm = inplaceClass!ConsoleManager(data);
	return cm;
}
