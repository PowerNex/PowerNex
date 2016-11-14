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

	spawnShell("/IO/Console/VirtualConsole4");
	spawnShell("/IO/Console/VirtualConsole3");
	spawnShell("/IO/Console/VirtualConsole2");
	spawnShell("/IO/Console/VirtualConsole1");

	while (true)
		Syscall.Join(0);
}

void spawnShell(string virtConsole) {
	ulong pid = Syscall.Fork();
	if (!pid) {
		Syscall.ReOpen(0, virtConsole);
		Syscall.Exec("/Binary/Shell", []);
		Syscall.Exit(1);
	}
}
