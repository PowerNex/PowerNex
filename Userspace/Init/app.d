extern (C) void _start() {
	asm {
		naked;
		mov RBP, RSP;
		call dmain;
		mov RDI, RAX;
		jmp exit;
	}
}

ulong ExitValue = 0;
__gshared align(16) ubyte[0x1000] CloneStack = void;

ulong dmain() {
	const(char)* HelloWorld = "Hello World from Userspace and D!";
	const(char)* TryClone = "Trying to clone!";
	const(char)* CloneName = "Cloned process!";
	const(char)* TryFork = "Trying to fork!";
	const(char)* ForkSuccess = "FORK WORKED!";

	printcstr(HelloWorld);

	printcstr(TryClone);
	clone(&cloneEntry, &CloneStack.ptr[0x1000], null, CloneName);

	ulong pid = fork();
	printcstr(ForkSuccess);

	if (!pid)
		return 0x31415;

	while (true)
		yield();
}

void cloneEntry() {
	asm {
		naked;
		mov RBP, RSP;
		call cloneFunction;
		mov RDI, RAX;
		jmp exit;
	}
}

ulong cloneFunction() {
	const(char)* CloneSuccess = "CLONE WORKED!\0";
	printcstr(CloneSuccess);

	ExitValue = 0x1337;

	return ExitValue;
}

ulong exit(ulong exitCode) {
	asm {
		naked;
		mov RAX, 0;
		int 0x80;
	exit_loop:
		hlt; // Should never happen
		jmp exit_loop;
	}
}

ulong printcstr(const(char)* str) {
	asm {
		mov RDI, str;
		mov RAX, 16;
		int 0x80;
	}
}

ulong clone(void function() func, void* stack, void* userdata, const(char)* name) {
	asm {
		mov RDI, func;
		mov RSI, stack;
		mov RDX, userdata;
		mov RCX, name;

		mov RAX, 1;
		int 0x80;
	}
}

ulong fork() {
	asm {
		mov RAX, 2;
		int 0x80;
	}
}

ulong yield() {
	asm {
		mov RAX, 3;
		int 0x80;
	}
}

// Hack below to make dmd compile the file

alias immutable(char)[] string;

extern (C) __gshared void* _Dmodule_ref;

extern (C) int __dmd_personality_v0(int, int, ulong, void*, void*) {
	return 0;
}

__gshared void* _minfo_beg;
__gshared void* _minfo_end;
__gshared immutable(void)* _deh_beg;
__gshared immutable(void)* _deh_end;

extern (C) void _d_dso_registry(void* data) {
}

/*void _d_array_bounds(ModuleInfo* m, uint line) {
		_d_arraybounds(m.name, line);
	}*/

extern (C) void _d_arraybounds(string m, uint line) {
	//throw new Error("Range error", m, line);
}

extern (C) void _d_unittest() {
}

extern (C) void _d_assert(string file, uint line) {
}
