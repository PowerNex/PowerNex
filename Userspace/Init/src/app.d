import PowerNex.Syscall;
import PowerNex.Data.Address;
import PowerNex.Data.String;

ulong ExitValue = 0;
__gshared align(16) ubyte[0x1000] CloneStack = void;

struct StructTest {
	int a;
}

class ClassTest {
public:
	this(int a) {
		this.o = a + 10;
	}

	@property int O() {
		return o;
	}

private:
	int o;
}

void Print(string str) {
	Syscall.Write(0UL, cast(ubyte[])str, 0UL);
}

void Println(string str) {
	Print(str);
	Print("\n");
}

int main(string[] args) {
	Println("Init system loading...");

	size_t fd = Syscall.Open("/IO/Console/VirtualConsole4");
	spawnShell(fd);
	Syscall.Close(fd);

	fd = Syscall.Open("/IO/Console/VirtualConsole3");
	spawnShell(fd);
	Syscall.Close(fd);

	fd = Syscall.Open("/IO/Console/VirtualConsole2");
	spawnShell(fd);
	Syscall.Close(fd);

	fd = Syscall.Open("/IO/Console/VirtualConsole1");
	spawnShell(fd);
	Syscall.Close(fd);
	while (true)
		Syscall.Join(0);
}

void spawnShell(size_t fd) {
	ulong pid = Syscall.Fork();
	if (!pid) {
		Syscall.SwapFD(0, fd);
		Syscall.Exec("/Binary/Shell", []);
		Syscall.Exit(1);
	}
}
