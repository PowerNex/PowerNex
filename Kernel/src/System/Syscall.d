module System.Syscall;

import CPU.IDT;
import Data.Register;

struct Syscall {
public:
	static void Init() {
		IDT.Register(0x80, &onSyscall);
	}

private:
	static void onSyscall(Registers* regs) {
		import Data.TextBuffer : scr = GetBootTTY;

		with (regs) switch (RAX) {
			foreach (func; __traits(derivedMembers, mixin(__MODULE__))) {
				foreach (attr; __traits(getAttributes, mixin(func))) {
					static if (is(typeof(attr) == SyscallEntry)) {
		case attr.id:
						mixin(generateFunctionCall!func);
					}
				}
			}
		default:
			scr.Writeln("UNKNOWN SYSCALL: ", cast(void*)RAX);
			regs.RAX = ulong.max;
		}
	}

	static string generateFunctionCall(alias func)() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";
		enum ABI = ["RDI", "RSI", "RDX", "RCX", "R8", "R9", "R10", "R11"];

		alias p = Parameters!(mixin(func));
		string o = func ~ "(";

		foreach (idx, val; p) {
			static if (idx)
				o ~= ", ";
			o ~= "cast(" ~ val.stringof ~ ")" ~ ABI[idx];
		}

		o ~= ");";
		return o;
	}

	template Parameters(func...) {
		static if (is(typeof(&func[0]) Fsym : Fsym*) && is(Fsym == function))
			static if (is(Fsym P == function))
				alias Parameters = P;
			else
				static assert(0, "argument has no parameters");
	}
}

private:

struct SyscallEntry {
	ulong id;
	string name;
	string description;
}

@SyscallEntry(0, "Exit", "This terminates the current running process")
ulong exit(ulong errorcode) {
	import Task.Scheduler : GetScheduler;

	GetScheduler.Exit(errorcode);
	return 0;
}

@SyscallEntry(1, "Yield", "Yield the current process")
ulong yield() {
	/*import Task.Scheduler : GetScheduler;

	GetScheduler.Exit(errorcode);*/
	return 0;
}
