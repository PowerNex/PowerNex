module io.fs.io.fsroot;

import io.fs;
import io.fs.io;

import io.fs.io.console;
import io.fs.io.framebuffer;

class IOFSRoot : FSRoot {
public:
	this() {
		auto root = new DirectoryNode(NodePermissions.defaultPermissions);
		root.name = "io";
		root.id = _idCounter++;
		super(root);

		addAt("/zero", new ZeroNode());
		addAt("/true", new BoolNode(true));
		addAt("/false", new BoolNode(false));

		Framebuffer[4] fbs;
		VirtualConsoleScreen[4] vcss;

		{
			addAt("/framebuffer/framebuffer1", fbs[0] = new BGAFramebuffer(1280, 720));
			addAt("/framebuffer/framebuffer2", fbs[1] = new BGAFramebuffer(1280, 720));
			addAt("/framebuffer/framebuffer3", fbs[2] = new BGAFramebuffer(1280, 720));
			addAt("/framebuffer/framebuffer4", fbs[3] = new BGAFramebuffer(1280, 720));
		}

		{
			import bin.consolefont;

			addAt("/consolescreen/virtualconsolescreen1", vcss[0] = new VirtualConsoleScreenFramebuffer(fbs[0], getConsoleFont()));
			addAt("/consolescreen/virtualconsolescreen2", vcss[1] = new VirtualConsoleScreenFramebuffer(fbs[1], getConsoleFont()));
			addAt("/consolescreen/virtualconsolescreen3", vcss[2] = new VirtualConsoleScreenFramebuffer(fbs[2], getConsoleFont()));
			addAt("/consolescreen/virtualconsolescreen4", vcss[3] = new VirtualConsoleScreenFramebuffer(fbs[3], getConsoleFont()));
		}

		{
			addAt("/console/virtualconsole1", new VirtualConsole(vcss[0]));
			addAt("/console/virtualconsole2", new VirtualConsole(vcss[1]));
			addAt("/console/virtualconsole3", new VirtualConsole(vcss[2]));
			addAt("/console/virtualconsole4", new VirtualConsole(vcss[3]));
		}

		{
			import io.com : com1, com2, com3, com4;

			addAt("/console/serialconsole1", new SerialConsole(com1));
			addAt("/console/serialconsole2", new SerialConsole(com2));
			addAt("/console/serialconsole3", new SerialConsole(com3));
			addAt("/console/serialconsole4", new SerialConsole(com4));
		}
	}
}
