module Bin.BasicShell;

import Task.Thread;
import Data.TextBuffer : scr = GetBootTTY;
import IO.Keyboard;
import Data.String;
import IO.Log;
import Memory.Heap;

class BasicShell {
public:
	void MainLoop() {
		log.Info("MEM###################################");
		GetKernelHeap.PrintLayout();
		log.Info("MEM2###################################");
		while (true) {
			scr.Write("> ");
			execute(parseLine(readLine));
		}
	}

private:
	enum Status {
		Valid,
		MissingEndBracket
	}

	struct Command {
		Status status;
		char[] name;
		char[][64] args;
		size_t argsCount;
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

	Command parseLine(char[] line) {
		char[] realLine = line;
		const long openBracket = line.indexOf('(');
		if (openBracket == -1)
			return Command(Status.Valid, line, []);

		Command cmd;
		cmd.name = line[0 .. openBracket].strip;
		line = line[openBracket + 1 .. $].strip;

		long comma = line.indexOf(',');
		while (comma != -1) {
			cmd.args[cmd.argsCount++] = line[0 .. comma].strip;
			line = line[comma + 1 .. $].strip;

			comma = line.indexOf(',');
		}
		//,)
		const long endBracket = line.indexOf(')');
		if (endBracket > 0) {
			cmd.args[cmd.argsCount++] = line[0 .. endBracket].strip;
		} else if (endBracket == -1)
			return Command(Status.MissingEndBracket, realLine, []);

		return cmd;
	}

	void execute(Command cmd) {
		switch (cmd.name) {
		case "help":
			scr.Writeln("Commands: help, echo, clear, exit, dlogo");
			break;

		case "echo":
			foreach (idx, arg; cmd.args[0 .. cmd.argsCount])
				scr.Write(arg, " ");
			scr.Writeln();
			break;
		case "clear":
			scr.Clear();
			break;

		case "exit":
			import ACPI.RSDP;
			import IO.Port;

			rsdp.Shutdown();
			scr.Writeln("Failed shutdown!");
			while (true) {
			}
			break;

		case "dlogo":

			log.Info("MEM33333###################################");
			GetKernelHeap.PrintLayout();
			log.Info("MEM444444###################################");
			import KMain;
			import IO.FS.FileNode;
			import Data.BMPImage;
			import HW.BGA.BGA;

			BMPImage bmp = new BMPImage(cast(FileNode)rootFS.Root.FindNode("/Data/DLogo.bmp"));
			GetBGA.RenderBMP(bmp);
			bmp.destroy;
			break;
		default:
			scr.Writeln("Unknown command: ", cmd.name);
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

private:
	__gshared BasicShell shell;
	static void run() {
		shell.MainLoop();
	}
}
