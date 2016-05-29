module Bin.BasicShell;

import Task.Thread;
import Data.TextBuffer : scr = GetBootTTY;
import IO.Keyboard;
import Data.String;
import IO.Log;
import Memory.Heap;

import ACPI.RSDP;
import KMain;
import IO.FS.FileNode;
import Data.BMPImage;
import HW.BGA.BGA;
import Memory.FrameAllocator;
import CPU.PIT;

class BasicShell {
public:
	this() {
		dlogo = new BMPImage(cast(FileNode)rootFS.Root.FindNode("/Data/DLogo.bmp"));
	}

	~this() {
		dlogo.destroy;
	}

	void MainLoop() {
		while (true) {
			scr.Write("> ");
			Command* command = parseLine(readLine);
			if (command.args.length)
				execute(command);
			command.destroy;
			GetKernelHeap.PrintLayout();
		}
	}

private:
	BMPImage dlogo;

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
			else if (ch == '\b') {
				if (idx) {
					idx--;
					line[ch] = ' ';
					scr.Write("\b \b");
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
			scr.Writeln("Commands: help, echo, clear, exit, dlogo, memory, sinceboot");
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

		case "dlogo":
			GetBGA.RenderBMP(dlogo);
			break;

		case "memory":
			const ulong usedMiB = FrameAllocator.UsedFrames / 256;
			const ulong maxMiB = FrameAllocator.MaxFrames / 256;
			ulong memory;
			if (maxMiB)
				memory = (usedMiB * 100) / maxMiB;
			scr.Writeln("Memory used: ", usedMiB, "MiB/", maxMiB, "MiB(", memory, "%)");
			break;

		case "sinceboot":
			scr.Writeln("Seconds since boot: ", PIT.Seconds);

			break;
		default:
			scr.Writeln("Unknown command: ", cmd.args[0], ". Type 'help' for all the commands.");
			break;
		}
	}
}

class BasicShellThread : KernelThread {
public:
	this() {
		shell = new BasicShell();
		super(&run);
	}

	~this() {
		shell.destroy;
	}

private:
	__gshared BasicShell shell;
	static void run() {
		shell.MainLoop();
	}
}
