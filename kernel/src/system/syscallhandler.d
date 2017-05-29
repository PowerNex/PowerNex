module system.syscallhandler;

import cpu.idt;
import cpu.msr;
import data.register;
import system.syscall;
import data.parameters;
import data.address;

extern (C) void onSyscall();

// for syscallhelper.S
extern (C) void _onSyscallHandler() {
	asm {
		naked;
		jmp SyscallHandler._onSyscallHandler;
	}
}

struct SyscallHandler {
public:
	static void init() {
		enum ulong userCS = 0x18 | 0x3;
		enum ulong kernelCS = 0x8;
		enum ulong eflagsInterrupt = 1 << 9;

		MSR.star = (kernelCS << 32UL | userCS << 48UL);
		MSR.lStar = cast(ulong)&onSyscall;
		MSR.sfMask = eflagsInterrupt;

		IDT.register(0x80, &_onSyscallHandler);

		import task.process;

		//XXX: Make generation of this value
		pragma(msg, "Don't forget to update kernelStack in syscallhelper.S to this value: ",
				Process.image.offsetof + ImageInformation.kernelStack.offsetof);
	}

private:
	static void _onSyscallHandler(Registers* regs) {
		import data.textbuffer : scr = getBootTTY;
		/*import task.scheduler : getScheduler;

		auto process = getScheduler.currentProcess;

		(*process).syscallRegisters = *regs;*/
		with (regs)/*
	outer : switch (cast(SyscallID)rax) {
			foreach (func; __traits(derivedMembers, system.syscall)) {
				static if (is(typeof(mixin("system.syscall." ~ func)) == function))
					foreach (attr; __traits(getAttributes, mixin("system.syscall." ~ func))) {
						static if (is(typeof(attr) == SyscallEntry)) {
		case attr.id:
							mixin(_generateFunctionCall!func);
							break outer;
						}
					}
			}
		default:*/
			scr.writeln("UNKNOWN SYSCALL: ", cast(void*)rax);
			/*(*process).syscallRegisters.rax = ulong.max;
			break;
		}
		*regs = (*process).syscallRegisters;*/
	}

	private static string _generateFunctionCall(alias func)() {
		if (!__ctfe) { // Without this it tries to use _d_arrayappendT
			assert(0);
			return "";
		} else {
			import data.util : isArray;

			enum abi = ["rdi", "rsi", "rdx", "r8", "r9", "r10", "r12", "r13", "r14", "r15"];

			alias p = parameters!(mixin("system.syscall." ~ func));
			string o = "system.syscall." ~ func ~ "(";

			size_t abi_count;
			foreach (idx, val; p) {
				assert(abi_count < abi.length);
				static if (idx)
					o ~= ", ";
				static if (isArray!val) {
					o ~= abi[abi_count++];
					assert(abi_count < abi.length);
					o ~= ".array!(" ~ val.stringof ~ ")(" ~ abi[abi_count++] ~ ")";
				} else
					o ~= "cast(" ~ val.stringof ~ ")" ~ abi[abi_count++] ~ ".num"; //!(" ~ val.stringof ~ ")";
			}

			o ~= ");";
			return o;
		}
	}
}
