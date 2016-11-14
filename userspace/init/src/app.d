import powernex.syscall;
import powernex.data.address;
import powernex.data.string_;

ulong exitValue = 0;
__gshared align(16) ubyte[0x1000] cloneStack = void;

struct StructTest {
	int a;
}

class ClassTest {
public:
	this(int a) {
		_o = a + 10;
	}

	@property int o() {
		return _o;
	}

private:
	int _o;
}

void print(string str) {
	Syscall.write(0UL, cast(ubyte[])str, 0UL);
}

void println(string str) {
	print(str);
	print("\n");
}

int main(string[] args) {
	println("Init system loading...");

	spawnShell("/io/console/virtualconsole4");
	spawnShell("/io/console/virtualconsole3");
	spawnShell("/io/console/virtualconsole2");
	spawnShell("/io/console/virtualconsole1");

	while (true)
		Syscall.join(0);
}

void spawnShell(string virtConsole) {
	ulong pid = Syscall.fork();
	if (!pid) {
		Syscall.reOpen(0, virtConsole);
		Syscall.exec("/bin/shell", []);
		Syscall.exit(1);
	}
}
