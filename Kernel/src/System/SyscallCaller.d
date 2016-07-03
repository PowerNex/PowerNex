module System.SyscallCaller;

import System.Syscall;
import Data.Parameters;
import Data.Address;

struct SyscallCaller {
public:
	mixin(generateFunctions);

private:
	static string generateFunctions() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";
		string o;
		foreach (func; __traits(derivedMembers, System.Syscall)) {
			foreach (attr; __traits(getAttributes, mixin(func))) {
				static if (is(typeof(attr) == SyscallEntry)) {
					o ~= generateFunctionDefinition!(func, attr) ~ "\n";
				}
			}
		}
		return o;
	}

	static string generateFunctionDefinition(alias func, alias attr)() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";
		enum NAME = ["a", "b", "c", "d", "e", "f", "g", "h"];
		enum ABI = ["RDI", "RSI", "RDX", "RCX", "R8", "R9", "R10", "R11"];

		alias p = Parameters!(mixin(func));
		string o = "static ulong " ~ func ~ "(";

		foreach (idx, val; p) {
			static if (idx)
				o ~= ", ";
			o ~= val.stringof ~ " " ~ NAME[idx];
		}
		o ~= ") {\n";

		import Data.String;

		char[ulong.sizeof * 8] buf;
		o ~= "\tasm {\n";
		o ~= "\t\tmov RAX, " ~ itoa(attr.id, buf) ~ ";\n";
		foreach (idx, val; p)
			o ~= "\t\tmov " ~ ABI[idx] ~ ", " ~ NAME[idx] ~ ";\n";
		o ~= "\t\tint 0x80;\n";
		o ~= "\t}\n}";
		return o;
	}
}
