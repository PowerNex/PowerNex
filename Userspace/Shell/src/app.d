import PowerNex.Syscall : Syscall;

int main(string[] args) {
	Syscall.Print("##########");
	Syscall.Print("This is the shell!");

	Syscall.Print("Arguments:");
	foreach (arg; args)
		Syscall.Print(arg);
	Syscall.Print("##########");
	return 0;
}
