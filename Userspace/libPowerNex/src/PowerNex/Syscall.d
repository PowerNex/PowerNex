module PowerNex.Syscall;

import PowerNex.Internal.Syscall;
import PowerNex.Data.Address;

struct Syscall {
public:
	mixin(generateFunctions);

private:
	static string generateFunctions() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";
		string o;
		foreach (func; __traits(derivedMembers, PowerNex.Internal.Syscall))
			foreach (attr; __traits(getAttributes, mixin(func)))
				static if (is(typeof(attr) == SyscallEntry))
					o ~= generateFunctionDefinition!(func, attr) ~ "\n";
		return o;
	}

	static string generateFunctionDefinition(alias func, alias attr)() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";

		import PowerNex.Data.Parameters;
		import PowerNex.Data.String : itoa;
		import PowerNex.Data.Util : isArray;

		// These can be used because they will be saved first
		string[] saveRegisters = ["R12", "R13", "R14", "R15"];
		enum NAME = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"];
		enum ABI = ["RDI", "RSI", "RDX", "R8", "R9", "R10", "R12", "R13", "R14", "R15"];

		alias p = Parameters!(mixin(func));
		string o = "static VirtAddress " ~ func ~ "(";

		foreach (idx, val; p) {
			static if (idx)
				o ~= ", ";
			o ~= val.stringof ~ " " ~ NAME[idx];
		}
		o ~= ") {\n";

		size_t registerCount;

		foreach (idx, val; p) {
			static if (!isArray!val) {
				registerCount++;
				continue;
			}
			o ~= "\tauto " ~ NAME[idx] ~ "_ptr = " ~ NAME[idx] ~ ".ptr;\n";
			o ~= "\tauto " ~ NAME[idx] ~ "_length = " ~ NAME[idx] ~ ".length;\n";
			registerCount += 2;
		}
		assert(registerCount < ABI.length);

		char[ulong.sizeof * 8] buf;
		o ~= "\tasm {\n";
		o ~= "\t\tpush RCX;\n";
		o ~= "\t\tpush R11;\n";

		if (registerCount > 5)
			foreach (save; saveRegisters[0 .. registerCount - 5])
				o ~= "\t\tpush " ~ save ~ ";\n";
		o ~= "\t\tmov RAX, " ~ itoa(attr.id, buf) ~ ";\n";

		size_t abi_count;
		foreach (idx, val; p) {
			static if (isArray!val) {
				o ~= "\t\tmov " ~ ABI[abi_count++] ~ ", " ~ NAME[idx] ~ "_ptr;\n";
				o ~= "\t\tmov " ~ ABI[abi_count++] ~ ", " ~ NAME[idx] ~ "_length;\n";
			} else
				o ~= "\t\tmov " ~ ABI[abi_count++] ~ ", " ~ NAME[idx] ~ ";\n";
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
