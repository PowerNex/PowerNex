module System.SyscallHandler;

import CPU.IDT;
import CPU.MSR;
import Data.Register;
import System.Syscall;
import Data.Parameters;
import Data.Address;

extern (C) void onSyscall();

struct SyscallHandler {
public:
	static void Init() {
		enum ulong USER_CS = 0x18 | 0x3;
		enum ulong KERNEL_CS = 0x8;
		enum ulong EFLAGS_INTERRUPT = 1 << 9;

		MSR.Star = (KERNEL_CS << 32UL | USER_CS << 48UL);
		MSR.LStar = cast(ulong)&onSyscall;
		MSR.SFMask = EFLAGS_INTERRUPT;

		IDT.Register(0x80, &onSyscallHandler);

		import Task.Process;

		//XXX: Make generation of this value
		pragma(msg, "Don't forget to update KERNEL_STACK in SyscallHelper.S to this value: ",
				Process.image.offsetof + ImageInformation.kernelStack.offsetof);
	}

private:
	static void onSyscallHandler(Registers* regs) {
		import Data.TextBuffer : scr = GetBootTTY;
		import Task.Scheduler : GetScheduler;

		auto process = GetScheduler.CurrentProcess;

		process.syscallRegisters = *regs;
		with (regs)
	outer : switch (RAX) {
			foreach (func; __traits(derivedMembers, System.Syscall)) {
				foreach (attr; __traits(getAttributes, mixin(func))) {
					static if (is(typeof(attr) == SyscallEntry)) {
		case attr.id:
						mixin(generateFunctionCall!func);
						break outer;
					}
				}
			}
		default:
			scr.Writeln("UNKNOWN SYSCALL: ", cast(void*)RAX);
			process.syscallRegisters.RAX = ulong.max;
			break;
		}
		*regs = process.syscallRegisters;
	}

	static string generateFunctionCall(alias func)() {
		if (!__ctfe) // Without this it tries to use _d_arrayappendT
			return "";
		import Data.Util : isArray;

		enum ABI = ["RDI", "RSI", "RDX", "R8", "R9", "R10", "R12", "R13", "R14", "R15"];

		alias p = Parameters!(mixin(func));
		string o = func ~ "(";

		size_t abi_count;
		foreach (idx, val; p) {
			assert(abi_count < ABI.length);
			static if (idx)
				o ~= ", ";
			static if (isArray!val) {
				o ~= "cast(" ~ val.stringof ~ ")" ~ ABI[abi_count++];
				assert(abi_count < ABI.length);
				o ~= ".Ptr[0.." ~ ABI[abi_count++] ~ "]";
			} else
				o ~= "cast(" ~ val.stringof ~ ")" ~ ABI[abi_count++] ~ ".Ptr";
		}

		o ~= ");";
		return o;
	}
}
