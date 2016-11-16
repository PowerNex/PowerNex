import powernex.syscall;
import powernex.data.string_;

void print(string str) {
	Syscall.write(0UL, cast(ubyte[])str, 0UL);
}

void print(char[] str) {
	print(cast(string)str);
}

void print(char ch) {
	Syscall.write(0UL, cast(ubyte[])(&ch)[0 .. 1], 0UL);
}

void print(T)(T t) if (is(T == enum)) {
	import powernex.data.util;

	char[ulong.sizeof * 8] buf;

	foreach (i, e; enumMembers!T)
		if (t == e) {
			print(__traits(allMembers, T)[i]);
			goto done;
		}
	print("cast(");
	print(T.stringof);
	print(")");
	print(itoa(cast(ulong)t, buf, 10));
done:
}

void println() {
	print("\n");
}

void println(string str) {
	print(str);
	println();
}

int main(string[] args) {
	while (true) {
		println("Booting up shell...");

		BasicShell bs = new BasicShell();
		bs.mainLoop();
		bs.destroy;
		println("\x1B[2J");
	}

	return 0;
}

struct DirectoryListing {
	enum Type {
		unknown,
		file,
		directory
	}

	size_t id;
	char[256] name;
	Type type;
}

class BasicShell {
public:
	void mainLoop() {
		char[0x100] cwd;
		while (!_quit) {
			size_t len = Syscall.getCurrentDirectory(cwd);
			print(cwd[0 .. len]);
			print("/ \u0017 ");
			Command* command = _parseLine(_readLine);
			if (command.args.length)
				_execute(command);
			command.destroy;
		}
	}

private:
	bool _quit;

	struct Command {
		char[][] args;

		~this() {
			args.destroy;
		}
	}

	char[] _readLine() {
		__gshared char[1024] line;
		ubyte[1024] buf;
		size_t idx = 0;

		while (idx < 1024) {
			size_t r = Syscall.read(0, buf[idx .. $], 0);
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
						print("\b \b"); // Back ' ' Back
					}
					continue;
				} else if (ch == '\n')
					goto done;
				print(ch);
				line[idx++] = ch;
			}
		}
	done:

		print("\n");
		return line[0 .. idx];
	}

	Command* _parseLine(char[] line) {
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

	void _execute(Command* cmd) {
		switch (cmd.args[0]) {
		case "help":
			println("Commands: help, echo, clear, exit, time, sleep, ls, cd");
			break;

		case "exit":
			_quit = true;
			break;

		case "clear":
			println("\x1B[2J");
			break;

		case "echo":
			foreach (idx, arg; cmd.args[1 .. $]) {
				print(arg);
				print(" ");
			}
			println();
			break;

		case "time":
			ulong timestamp = Syscall.getTimestamp;
			print("Current timestamp: ");
			char[ulong.sizeof * 8] buf;
			println(itoa(timestamp, buf, 10));
			break;

		case "sleep":
			if (cmd.args.length == 1) {
				println("sleep: <seconds>");
				break;
			}
			ulong secs = atoi(cast(string)cmd.args[1]);
			Syscall.sleep(secs * 1000);
			break;

		case "ls":
			DirectoryListing[32] listings = void;
			void* ptr = cast(void*)listings.ptr;
			size_t len = listings.length;
			size_t count;

			if(cmd.args.length == 1)
				count = Syscall.listDirectory(null, ptr, len);
			else
				count = Syscall.listDirectory(cast(string)cmd.args[1], ptr, len);

			println("ID\tName\t\tType");
			foreach (list; listings[0 .. count]) {
				char[ulong.sizeof * 8] buf;
				print(itoa(list.id, buf, 10));
				print(":\t");
				print(list.name.fromStringz);
				print("\t\t");
				print(list.type);
				println();
			}
			break;

		case "cd":
			if (cmd.args.length == 1)
				Syscall.changeCurrentDirectory("/");
			else
				Syscall.changeCurrentDirectory(cast(string)cmd.args[1]);
			break;

		default:
			size_t ret = _spawnAndWait(cmd);
			println();
			print("> Program returned: 0x");
			char[ulong.sizeof * 8] buf;
			println(itoa(ret, buf, 16));
			break;
		}
	}

	size_t _spawnAndWait(Command* cmd) {
		size_t pid = Syscall.fork();

		if (!pid) {
			size_t status = Syscall.exec(cast(string)cmd.args[0], cast(string[])cmd.args);
			println("Failed to launch program!");
			Syscall.exit(status);
		}

		return Syscall.join(pid);
	}
}
