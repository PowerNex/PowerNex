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
	println("Booting up shell...");

	BasicShell bs = new BasicShell();
	bs.mainLoop();
	bs.destroy;
	println("\x1B[2J");
	Syscall.exec("/bin/login", []);
	return 1;
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
			ssize_t r = Syscall.read(0, buf[idx .. $], 0);
			if (r < 0)
				continue;
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
			DirectoryListing[16] listings = void;

			size_t curr = 0;
			size_t count = listings.length;

			println("Name\t\tType");

			while (count == listings.length) {
				if (cmd.args.length == 1)
					count = Syscall.listDirectory(null, listings[], curr);
				else
					count = Syscall.listDirectory(cast(string)cmd.args[1], listings[], curr);
				if (count == size_t.max) {
					println("===ERROR while calling listDirectory==="); //TODO: print real error
					break;
				}

				curr += listings.length;
				foreach (list; listings[0 .. count]) {
					char[ulong.sizeof * 8] buf;
					print(list.name.fromStringz);
					print(":\t");
					print(list.type);
					println();
				}
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
