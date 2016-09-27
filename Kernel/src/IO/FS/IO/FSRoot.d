module IO.FS.IO.FSRoot;

import IO.FS;
import IO.FS.IO;

import IO.FS.IO.Console;
import IO.FS.IO.Framebuffer;

__gshared VirtualConsole[4] virtualConsoles; //XXX:

class IOFSRoot : FSRoot {
public:
	this() {
		auto root = new DirectoryNode(NodePermissions.DefaultPermissions);
		root.Name = "IO";
		root.ID = idCounter++;
		super(root);

		addAt("/Zero", new ZeroNode());
		addAt("/True", new BoolNode(true));
		addAt("/False", new BoolNode(false));
		addAt("/StandardIO", new SoftLinkNode(NodePermissions.DefaultPermissions, "Console/Console0"));
		addAt("/stdout", new SoftLinkNode(NodePermissions.DefaultPermissions, "Console/Console0"));
		addAt("/stdin", new SoftLinkNode(NodePermissions.DefaultPermissions, "Console/Console0"));
		addAt("/stderr", new SoftLinkNode(NodePermissions.DefaultPermissions, "Console/Console0"));

		Framebuffer[4] fbs;
		VirtualConsoleScreen[4] vcss;

		{
			addAt("/Framebuffer/CurrentFramebuffer", new SoftLinkNode(NodePermissions.DefaultPermissions, "Framebuffer/BGAFramebuffer1"));
			addAt("/Framebuffer/Framebuffer1", fbs[0] = new BGAFramebuffer(1280, 720));
			addAt("/Framebuffer/Framebuffer2", fbs[1] = new BGAFramebuffer(1280, 720));
			addAt("/Framebuffer/Framebuffer3", fbs[2] = new BGAFramebuffer(1280, 720));
			addAt("/Framebuffer/Framebuffer4", fbs[3] = new BGAFramebuffer(1280, 720));
		}

		{
			import Bin.ConsoleFont;

			addAt("/ConsoleScreen/VirtualConsoleScreen1", vcss[0] = new VirtualConsoleScreenFramebuffer(fbs[0], GetConsoleFont()));
			addAt("/ConsoleScreen/VirtualConsoleScreen2", vcss[1] = new VirtualConsoleScreenFramebuffer(fbs[1], GetConsoleFont()));
			addAt("/ConsoleScreen/VirtualConsoleScreen3", vcss[2] = new VirtualConsoleScreenFramebuffer(fbs[2], GetConsoleFont()));
			addAt("/ConsoleScreen/VirtualConsoleScreen4", vcss[3] = new VirtualConsoleScreenFramebuffer(fbs[3], GetConsoleFont()));
		}

		{
			addAt("/Console/VirtualConsole1", virtualConsoles[0] = new VirtualConsole(vcss[0]));
			addAt("/Console/VirtualConsole2", virtualConsoles[1] = new VirtualConsole(vcss[1]));
			addAt("/Console/VirtualConsole3", virtualConsoles[2] = new VirtualConsole(vcss[2]));
			addAt("/Console/VirtualConsole4", virtualConsoles[3] = new VirtualConsole(vcss[3]));
		}

		{
			import IO.COM : COM1, COM2, COM3, COM4;

			addAt("/Console/SerialConsole1", new SerialConsole(COM1));
			addAt("/Console/SerialConsole2", new SerialConsole(COM2));
			addAt("/Console/SerialConsole3", new SerialConsole(COM3));
			addAt("/Console/SerialConsole4", new SerialConsole(COM4));
		}

	}
}
