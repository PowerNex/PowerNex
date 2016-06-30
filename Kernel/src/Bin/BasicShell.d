module Bin.BasicShell;

import Data.TextBuffer : scr = GetBootTTY;
import IO.Keyboard;
import Data.String;
import Data.Address;
import IO.Log;
import Memory.Heap;

import ACPI.RSDP;
import KMain;
import IO.FS;
import Data.BMPImage;
import HW.BGA.BGA;
import Memory.FrameAllocator;
import CPU.PIT;
import HW.CMOS.CMOS;

VirtAddress RunBasicShell()
{
	auto shell = new BasicShell();
	shell.MainLoop();
	shell.destroy();
	return VirtAddress(0);
}

class BasicShell {
public:
	this() {
		cwd = rootFS.Root;
	}

	~this() {
	}

	void MainLoop() {
		void printName(DirectoryNode node) {
			if (node.Parent) {
				printName(node.Parent);
				scr.Write("/", node.Name);
			}
		}

		while (true) {
			printName(cwd);
			scr.Write("/ \u0017 ");
			Command* command = parseLine(readLine);
			if (command.args.length)
				execute(command);
			command.destroy;
		}
	}

private:
	DirectoryNode cwd;

	struct Command {
		char[][] args;

		~this() {
			args.destroy;
		}
	}

	char[] readLine() {
		__gshared char[1024] line;
		size_t idx = 0;

		while (idx < 1024) {
			char ch = cast(char)Keyboard.Pop();
			if (ch == '\0')
				continue;
			else if (ch == '\t')
				continue;
			else if (ch == '\b') {
				if (idx) {
					idx--;
					line[idx] = ' ';
					scr.Write("\b \b"); // Back ' ' Back
				}
				continue;
			} else if (ch == '\n')
				break;
			scr.Write(ch);
			line[idx++] = ch;
		}

		scr.Write('\n');
		return line[0 .. idx];
	}

	Command* parseLine(char[] line) {
		char[][] args;

		size_t start = 0;
		size_t end = line.indexOf(' ', start);
		while (end != -1) {
			args[args.length++] = line[start .. end];
			start = end + 1;
			end = line.indexOf(' ', start);
		}

		if (start < line.length)
			args[args.length++] = line[start .. line.length];

		return new Command(args);
	}

	void execute(Command* cmd) {
		switch (cmd.args[0]) {
		case "help":
			scr.Writeln("Commands: help, echo, clear, exit, memory, time, ls, cd, cat");
			break;

		case "echo":
			foreach (idx, arg; cmd.args[1 .. $])
				scr.Write(arg, " ");
			scr.Writeln();
			break;
		case "clear":
			scr.Clear();
			break;

		case "exit":
			rsdp.Shutdown();
			scr.Writeln("Failed shutdown!");
			while (true) {
			}
			break;

		case "memory":
			const ulong usedMiB = FrameAllocator.UsedFrames / 256;
			const ulong maxMiB = FrameAllocator.MaxFrames / 256;
			ulong memory;
			if (maxMiB)
				memory = (usedMiB * 100) / maxMiB;
			scr.Writeln("Memory used: ", usedMiB, "MiB/", maxMiB, "MiB(", memory, "%)");
			break;

		case "time":
			ulong timestamp = GetCMOS.TimeStamp;
			ulong sinceBoot = PIT.Seconds;

			scr.Writeln("The machine booted at: ", timestamp);
			scr.Writeln("Seconds since boot: ", sinceBoot);
			scr.Writeln("Which means that the time should be: ", timestamp + sinceBoot);
			break;

		case "ls":
			scr.Writeln("ID\tName\t\tType");
			foreach (Node node; cwd.Nodes) {
				char[] name = cast(char[])typeid(node).name;
				scr.Writeln(node.ID, ":\t", node.Name, "\t\t", name[name.indexOfLast('.') + 1 .. $]);
			}
			break;

		case "cd":
			if (cmd.args.length == 1)
				cwd = rootFS.Root; // Defaults to /
			else if (cmd.args[1] == ".") {
				//Nothing
			} else if (cmd.args[1] == "..") {
				if (cwd.Parent)
					cwd = cwd.Parent;
			} else {
				Node node = cwd.FindNode(cast(string)cmd.args[1]);
				if (!node) {
					scr.Writeln("Can't find the node!");
					break;
				}
				if (auto dir = cast(DirectoryNode)node)
					cwd = dir;
				else {
					char[] name = cast(char[])typeid(node).name;
					scr.Writeln("Can't cd into a ", name[name.indexOfLast('.') + 1 .. $]);
				}
			}
			break;

		case "cat":
			if (cmd.args.length == 1)
				scr.Writeln("cat: <FilePath>");
			else {
				foreach (file; cmd.args[1 .. $]) {
					Node node = cwd.FindNode(cast(string)file);
					if (!node) {
						scr.Writeln("Can't find the file '", file, "'!");
						continue;
					}
					if (auto f = cast(FileNode)node) {
						if (file[$ - 4 .. $] == ".bmp") {
							BMPImage img = new BMPImage(f);
							GetBGA.RenderBMP(img);
							img.destroy();
						} else {
							ubyte[] buf = new ubyte[0x1000];

							ulong read;
							ulong offset;
							do {
								read = f.Read(buf, offset);
								offset += read;
								scr.Write(cast(char[])buf[0 .. read]);
							}
							while (read == 0x1000);
							scr.Writeln();
						}
					} else {
						char[] name = cast(char[])typeid(node).name;
						scr.Writeln("Can't cat a ", name[name.indexOfLast('.') + 1 .. $]);
					}
				}
			}
			break;
		default:
			scr.Writeln("Unknown command: ", cmd.args[0], ". Type 'help' for all the commands.");
			break;
		}
	}
}

__EOF__ class BasicShellThread : KernelThread {
	public : this() {
		shell = new BasicShell();
		super( & run);
	}

	~this() {
		shell.destroy;
	}

	private : __gshared BasicShell shell;
	static void run() {
		shell.MainLoop();
	}
}
