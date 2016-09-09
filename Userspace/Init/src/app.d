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

int main(string[] args) {
	Syscall.Print("Hello World from Userspace and D!");

	Syscall.Print("Arguments:");
	foreach (arg; args)
		Syscall.Print(arg);
	Syscall.Print("");

	Syscall.Print("Trying to clone!");
	Syscall.Clone(&cloneEntry, VirtAddress(&CloneStack.ptr[0x1000]), null, "Cloned process!");

	Syscall.Print("Testing fork...");
	ulong pid = Syscall.Fork();

	if (!pid) {
		Syscall.Print("Fork child!");
		return 0x31415;
	} else
		Syscall.Print("Fork parent!");

	Syscall.Print("Testing StructTest...");
	StructTest sTest = StructTest(1327);
	Syscall.Print("Testing ClassTest...");
	ClassTest cTest = new ClassTest(sTest.a);

	char[17] buf;
	Syscall.Print("ClassTest.O = ");
	Syscall.Print(itoa(cTest.O, buf));
	while (true)
		Syscall.Yield();
}

ulong cloneEntry(void* userdata) {
	asm {
		naked;
		mov RBP, RSP;
		call cloneFunction;
		mov RDI, RAX;
		jmp Syscall.Exit;
	}
}

ulong cloneFunction() {
	Syscall.Print("CLONE WORKED!");

	ExitValue = 0xDEAD_DEAD_DEAD_DEAD;

	Syscall.Exit(ExitValue);
	return ExitValue;
}
