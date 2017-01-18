module init;

import powernex.syscall;

void print(string str) {
	Syscall.write(0UL, cast(ubyte[])str, 0UL);
}

void println(string str) {
	print(str);
	print("\n");
}

int main(string[] args) {
	println("Init system loading...");

	if (!Syscall.fork()) {
		Syscall.exec("/bin/login", []);
		println("Failed to start /bin/login! Is is missing?");
		while (true) {
		}
	}
	while (true)
		Syscall.join(0);
}
