import powernex.syscall;
import powernex.data.address;
import powernex.data.string_;

void print(string str) {
	Syscall.write(0UL, cast(ubyte[])str, 0UL);
}

void println(string str) {
	print(str);
	print("\n");
}

int main(string[] args) {
	if (args.length == 1) {
		print(args[0]);
		println(": <File 0> <File 1> ... <File N>");
		return 0;
	}
	foreach (file; args[1 .. $]) {
		print("*");
		print(file);
		println("*");
		size_t fd = Syscall.open(file);
		if (!fd) {
			println("File not found!");
			continue;
		}
		ubyte[0x1000] buf;

		size_t r = 0;
		size_t offset = 0;
		do {
			r = Syscall.read(fd, buf, offset);
			offset += r;
			print(cast(string)buf[0 .. r]);
		}
		while (r);
		Syscall.close(fd);
	}
	return 0;
}
