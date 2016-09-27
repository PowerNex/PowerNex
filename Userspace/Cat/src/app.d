import PowerNex.Syscall;
import PowerNex.Data.Address;
import PowerNex.Data.String;

void Print(string str) {
	Syscall.Write(0UL, cast(ubyte[])str, 0UL);
}

void Println(string str) {
	Print(str);
	Print("\n");
}

int main(string[] args) {
	if (args.length == 1) {
		Print(args[0]);
		Println(": <File 0> <File 1> ... <File N>");
		return 0;
	}
	foreach (file; args[1 .. $]) {
		Print("*");
		Print(file);
		Println("*");
		size_t fd = Syscall.Open(file);
		if (!fd) {
			Println("File not found!");
			continue;
		}
		ubyte[0x1000] buf;

		size_t r = 0;
		size_t offset = 0;
		do {
			r = Syscall.Read(fd, buf, offset);
			offset += r;
			Print(cast(string)buf[0 .. r]);
		}
		while (r);
		Syscall.Close(fd);
	}
	return 0;
}
