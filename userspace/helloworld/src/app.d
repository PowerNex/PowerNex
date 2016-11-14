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
	println("Hello World from Userspace and D!");
	return 0;
}
