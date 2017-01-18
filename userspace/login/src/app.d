module login;
import powernex.syscall;

void print(char ch) {
	char[] str = [ch];
	Syscall.write(0UL, cast(ubyte[])str, 0UL);
}

void print(string str) {
	Syscall.write(0UL, cast(ubyte[])str, 0UL);
}

void println(string str) {
	print(str);
	print("\n");
}

size_t readLine(ref char[1024] line, bool hidden = false) {
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
			print(hidden ? '*' : ch);
			line[idx++] = ch;
		}
	}
done:
	print("\n");
	return idx;
}

int main(string[] args) {
	println("Welcome to PowerNex OS! Please login below to access the system.");

	char[1024] username;
	char[1024] password;
	while (true) {
		print("\nUsername: ");
		size_t userlen = readLine(username);
		print("Password: ");
		size_t passlen = readLine(password, true);

		if (username[0 .. userlen] == "root" && password[0 .. passlen] == "root")
			break;

		println("Please try again!");
	}

	Syscall.exec("/bin/shell", []);
	return 1;
}
