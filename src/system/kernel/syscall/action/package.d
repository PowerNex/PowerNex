module syscall.action;
/*
private alias tuple(T...) = T;
private template ImportSyscall(T...) {

	string ImportSyscall;

	static foreach (t; T) {
		ImportSyscall ~= "public import syscall.action." ~ t ~ ";\n";
	}

ImportSyscall ~= "alias Syscalls = tuple!(";
	static foreach (t; T) {

			foreach (func; __traits(allMembers, mixin("syscall.action."~t))
				foreach (attr; __traits(getAttributes, mixin(func)))
					static if (is(typeof(attr) == Syscall)) {
						ImportSyscall~= "func"
					}

	}
}

mixin(ImportSyscall!());*/

public import syscall.action.exit;
public import syscall.action.yield;
public import syscall.action.write;
public import syscall.action.fork;

enum string[] SyscallModules = ["exit", "yield", "write", "fork"];
