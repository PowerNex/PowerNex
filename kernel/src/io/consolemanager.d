module io.consolemanager;

import io.fs.io.console;

class ConsoleManager {
public:
	void init() {
		import kmain : rootFS;
		import io.fs;
		import io.log;

		DirectoryNode csDir = cast(DirectoryNode)rootFS.root.findNode("/io/console");
		if (!csDir)
			log.error("/io/console/ missing");

		auto nodes = csDir.nodes;
		_vcs = new VirtualConsole[4]; //XXX:
		size_t idx = 0;
		foreach (node; nodes) {
			if (auto _ = cast(VirtualConsole)node)
				_vcs[idx++] = _;
		}

		_vcs[_active].active = true;
	}

	void addKeyboardInput(dchar ch, bool ctrl, bool alt, bool shift) {
		if (!_vcs.length)
			return;

		if ((ch >= '1' || ch <= '9') && alt) {
			size_t want = ch - '1';
			if (want < _vcs.length && want != _active) {
				_vcs[_active].active = false;
				_active = want;
				_vcs[_active].active = true;
			}
		} else
			_vcs[_active].addKeyboardInput(ch);
	}

	@property VirtualConsole[] virtualConsoles() {
		return _vcs;
	}

private:
	size_t _active;
	VirtualConsole[] _vcs;
}

ConsoleManager getConsoleManager() {
	import data.util : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, ConsoleManager)] data;
	__gshared ConsoleManager cm;

	if (!cm)
		cm = inplaceClass!ConsoleManager(data);
	return cm;
}
