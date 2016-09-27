import PowerNex.Syscall;
import PowerNex.Data.String;

void Print(string str) {
	Syscall.Write(0UL, cast(ubyte[])str, 0UL);
}

void Print(char[] str) {
	Print(cast(string)str);
}

void Print(char ch) {
	Syscall.Write(0UL, cast(ubyte[])(&ch)[0 .. 1], 0UL);
}

void Print(T)(T t) if (is(T == enum)) {
	import PowerNex.Data.Util;

	char[ulong.sizeof * 8] buf;

	foreach (i, e; EnumMembers!T)
		if (t == e) {
			Print(__traits(allMembers, T)[i]);
			goto done;
		}
	Print("cast(");
	Print(T.stringof);
	Print(")");
	Print(itoa(cast(ulong)t, buf, 10));
done:
}

void Println() {
	Print("\n");
}

void Println(string str) {
	Print(str);
	Println();
}

int main(string[] args) {
	while (true) {
		Println("Booting up shell...");

		BasicShell bs = new BasicShell();
		bs.MainLoop();
		bs.destroy;
		Println("\x1B[2J");
	}

	return 0;
}

struct DirectoryListing {
	enum Type {
		Unknown,
		File,
		Directory,
	}

	size_t id;
	char[256] name;
	Type type;
}

class BasicShell {
public:
	void MainLoop() {
		char[0x100] cwd;
		while (!quit) {
			size_t len = Syscall.GetCurrentDirectory(cwd);
			Print(cwd[0 .. len]);
			Print("/ \u0017 ");
			Command* command = parseLine(readLine);
			if (command.args.length)
				execute(command);
			command.destroy;
		}
	}

private:
	bool quit;

	struct Command {
		char[][] args;

		~this() {
			args.destroy;
		}
	}

	char[] readLine() {
		__gshared char[1024] line;
		ubyte[1024] buf;
		size_t idx = 0;

		while (idx < 1024) {
			size_t r = Syscall.Read(0, buf[idx .. $], 0);
			for (size_t i = 0; i < r; i++) {
				char ch = cast(char)buf[idx + i];
				if (ch == '\0')
					continue;
				else if (ch == '\t')
					continue;
				else if (ch == '\b') {
					if (idx) {
						idx--;
						line[idx] = ' ';
						Print("\b \b"); // Back ' ' Back
					}
					continue;
				} else if (ch == '\n')
					goto done;
				Print(ch);
				line[idx++] = ch;
			}
		}
	done:

		Print("\n");
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
			Println("Commands: help, echo, clear, exit, memory, time, sleep, ls, cd, cat");
			break;

		case "exit":
			quit = true;
			break;

		case "clear":
			Println("\x1B[2J");
			break;

		case "echo":
			foreach (idx, arg; cmd.args[1 .. $]) {
				Print(arg);
				Print(" ");
			}
			Println();
			break;

		case "time":
			ulong timestamp = Syscall.GetTimestamp;
			Print("Current timestamp: ");
			char[ulong.sizeof * 8] buf;
			Println(itoa(timestamp, buf, 10));
			break;

		case "sleep":
			if (cmd.args.length == 1) {
				Println("sleep: <seconds>");
				break;
			}
			ulong secs = atoi(cast(string)cmd.args[1]);
			Syscall.Sleep(secs * 1000);
			break;

		case "ls":
			DirectoryListing[32] listings = void;
			void* ptr = cast(void*)listings.ptr;
			size_t len = listings.length;
			size_t count = Syscall.ListDirectory(ptr, len);
			Println("ID\tName\t\tType");
			foreach (list; listings[0 .. count]) {
				char[ulong.sizeof * 8] buf;
				Print(itoa(list.id, buf, 10));
				Print(":\t");
				Print(list.name.fromStringz);
				Print("\t\t");
				Print(list.type);
				Println();
			}
			break;

		case "cd":
			if (cmd.args.length == 1)
				Syscall.ChangeCurrentDirectory("/");
			else
				Syscall.ChangeCurrentDirectory(cast(string)cmd.args[1]);
			break;

		default:
			size_t ret = SpawnAndWait(cmd);
			Println();
			Print("> Program returned: 0x");
			char[ulong.sizeof * 8] buf;
			Println(itoa(ret, buf, 16));
			break;
		}
	}

private:
	size_t SpawnAndWait(Command* cmd) {
		size_t pid = Syscall.Fork();

		if (!pid) {
			size_t status = Syscall.Exec(cast(string)cmd.args[0], cast(string[])cmd.args);
			Println("Failed to launch program!");
			Syscall.Exit(status);
		}

		return Syscall.Join(pid);
	}
}
