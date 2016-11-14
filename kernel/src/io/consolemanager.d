module IO.ConsoleManager;

import IO.FS.IO.Console;

class ConsoleManager {
public:
	void Init() {
		import KMain : rootFS;
		import IO.FS;
		import IO.Log;

		DirectoryNode csDir = cast(DirectoryNode)rootFS.Root.FindNode("/IO/Console");
		if (!csDir)
			log.Error("/IO/Console/ missing");

		auto nodes = csDir.Nodes;
		vcs = new VirtualConsole[4]; //XXX:
		size_t idx = 0;
		foreach (node; nodes) {
			if (auto _ = cast(VirtualConsole)node)
				vcs[idx++] = _;
		}

		vcs[active].Active = true;
	}

	void AddKeyboardInput(dchar ch, bool ctrl, bool alt, bool shift) {
		if (!vcs.length)
			return;

		if ((ch >= '1' || ch <= '9') && alt) {
			size_t want = ch - '1';
			if (want < vcs.length && want != active) {
				vcs[active].Active = false;
				active = want;
				vcs[active].Active = true;
			}
		} else
			vcs[active].AddKeyboardInput(ch);
	}

	@property VirtualConsole[] VirtualConsoles() {
		return vcs;
	}

private:
	size_t active;
	VirtualConsole[] vcs;
}

ConsoleManager GetConsoleManager() {
	import Data.Util : InplaceClass;

	__gshared ubyte[__traits(classInstanceSize, ConsoleManager)] data;
	__gshared ConsoleManager cm;

	if (!cm)
		cm = InplaceClass!ConsoleManager(data);
	return cm;
}
