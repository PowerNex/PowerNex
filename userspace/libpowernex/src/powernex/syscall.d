module powernex.syscall;

import powernex.internal.syscall;
import powernex.data.address;

struct Syscall {
public:
	mixin(_generateFunctions());

private:
	static string _generateFunctions() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";
		string o;
		foreach (func; __traits(derivedMembers, powernex.internal.syscall))
			static if (is(typeof(mixin("powernex.internal.syscall." ~ func)) == function))
				foreach (attr; __traits(getAttributes, mixin("powernex.internal.syscall." ~ func)))
					static if (is(typeof(attr) == SyscallEntry))
						o ~= _generateFunctionDefinition!(func, attr) ~ "\n";
		return o;
	}

	static string _generateFunctionDefinition(alias func, alias attr)() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";

		import powernex.data.parameters;
		import powernex.data.string_ : itoa;
		import powernex.data.util : isArray;

		// These can be used because they will be saved first
		string[] saveRegisters = ["R12", "R13", "R14", "R15"];
		enum name = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"];
		enum abi = ["RDI", "RSI", "RDX", "R8", "R9", "R10", "R12", "R13", "R14", "R15"];

		alias p = parameters!(mixin("powernex.internal.syscall." ~ func));
		string o = "static VirtAddress " ~ func ~ "(";

		foreach (idx, val; p) {
			static if (idx)
				o ~= ", ";
			o ~= val.stringof ~ " " ~ name[idx];
		}
		o ~= ") {\n";

		size_t registerCount;

		foreach (idx, val; p) {
			static if (!isArray!val) {
				registerCount++;
				continue;
			}
			o ~= "\tauto " ~ name[idx] ~ "_ptr = " ~ name[idx] ~ ".ptr;\n";
			o ~= "\tauto " ~ name[idx] ~ "_length = " ~ name[idx] ~ ".length;\n";
			registerCount += 2;
		}
		assert(registerCount < abi.length);

		char[ulong.sizeof * 8] buf;
		o ~= "\tasm {\n";
		o ~= "\t\tpush RCX;\n";
		o ~= "\t\tpush R11;\n";

		if (registerCount > 5)
			foreach (save; saveRegisters[0 .. registerCount - 5])
				o ~= "\t\tpush " ~ save ~ ";\n";
		o ~= "\t\tmov RAX, " ~ itoa(cast(ulong)attr.id, buf) ~ ";\n";

		size_t abi_count;
		foreach (idx, val; p) {
			static if (isArray!val) {
				o ~= "\t\tmov " ~ abi[abi_count++] ~ ", " ~ name[idx] ~ "_ptr;\n";
				o ~= "\t\tmov " ~ abi[abi_count++] ~ ", " ~ name[idx] ~ "_length;\n";
			} else
				o ~= "\t\tmov " ~ abi[abi_count++] ~ ", " ~ name[idx] ~ ";\n";
		}
		//o ~= "\t\tint 0x80;\n";
		o ~= "\t\tsyscall;\n";

		if (registerCount > 5)
			foreach_reverse (save; saveRegisters[0 .. registerCount - 5])
				o ~= "\t\tpop " ~ save ~ ";\n";

		o ~= "\t\tpop R11;\n";
		o ~= "\t\tpop RCX;\n";
		o ~= "\t}\n}";
		return o;
	}
}
