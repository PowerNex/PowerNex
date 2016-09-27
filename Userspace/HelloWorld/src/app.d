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
	Println("Hello World from Userspace and D!");
	return 0;
}
