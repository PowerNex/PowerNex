module syscall;

import stl.arch.amd64.idt;
import stl.arch.amd64.msr;
import stl.register;
import stl.trait;
import stl.address;

import arch.paging;

import task.scheduler;
import task.thread;

import syscall.action;

struct Syscall {
	size_t id;
}

struct SyscallArgument(T) {
	alias Argument = T;
	enum ArgumentString = T.stringof;
}

private struct SyscallStorage {
	VirtAddress kernelStack;
	VirtAddress userStack;
}

static assert(0x1000 / SyscallStorage.sizeof >= maxCPUCount);

struct SyscallHandler {
public static:
	void init(CPUInfo* cpuInfo) {
		import stl.vmm.paging : VMPageFlags;

		if (!_storage) {
			VirtAddress vAddr = makeAddress(510, 510, 510, 0);
			assert(mapAddress(vAddr, PhysAddress(), VMPageFlags.writable | VMPageFlags.present));

			_storage = vAddr.ptr!SyscallStorage[0 .. 0x1000 / SyscallStorage.sizeof];
		}

		_storage[cpuInfo.id].kernelStack = (cpuInfo.kernelStack.ptr.VirtAddress + 0x1000).num;

		MSR.star = (_kernelCS << 32UL | _userCS << 48UL);
		MSR.lStar = VirtAddress(onSyscallList[cpuInfo.id]);
		MSR.sfMask = _eflagsInterrupt;

		IDT.register(0x80, cast(IDT.InterruptCallback)&_onSyscallHandler);
	}

private static:
	enum ulong _userCS = 0x18 | 0x3;
	enum ulong _kernelCS = 0x8;
	enum ulong _eflagsInterrupt = 1 << 9;

	__gshared SyscallStorage[] _storage;
	__gshared void function()[] onSyscallList = () {
		void function()[] ret;
		static foreach (size_t i; 0 .. maxCPUCount)
			ret ~= &_onSyscall!i;
		return ret;
	}();

	void _onSyscall(size_t id)() {
		enum storageOffset = 0xFF7FBFDFE000 + id * 2 * ulong.sizeof;
		enum ulong* kernelStack = cast(ulong*)storageOffset;
		enum ulong* userStack = cast(ulong*)(storageOffset + 8);

		asm @trusted nothrow @nogc {
			naked;
			db 0x48, 0x0F, 0x07;
			/// -8[userStack] == Real RAX
			mov - 8[RSP], RAX;

			// mov %rsp, userStack
			mov RAX, userStack;
			mov qword ptr[RAX], RSP; /// *userStack = RSP;

			// mov kernelStack, %rsp
			mov RAX, kernelStack;
			mov RSP, [RAX]; /// RSP = *kernelStack

			mov RAX, userStack;
			// push userStack
			push[RAX]; /// *userStack

			push _userCS + 8; // SS
			push[RAX]; // RSP
			push R11; // Flags
			push _userCS; // CS
			push RCX; // RIP

			/// Restore RAX as it is no longer used
			mov RAX,  - 8[RAX]; // RAX = -8[userStack] aka restore RAX

			push 0; // ErrorCode
			push 0x80; // IntNumber

			push RAX;
			push RBX;
			push RCX;
			push RDX;
			push RSI;
			push RDI;
			push RBP;
			push R8;
			push R9;
			push R10;
			push R11;
			push R12;
			push R13;
			push R14;
			push R15;

			mov RDI, RSP;
			call _onSyscallHandler;
			jmp _returnFromSyscall;
		}
	}

	void _returnFromSyscall() {
		asm @trusted nothrow @nogc {
			naked;
			pop R15;
			pop R14;
			pop R13;
			pop R12;
			pop R11;
			pop R10;
			pop R9;
			pop R8;
			pop RBP;
			pop RDI;
			pop RSI;
			pop RDX;
			pop RCX;
			pop RBX;
			pop RAX;

			add RSP, 8 * 7;

			pop RSP;
			//sysretq;
			db 0x48, 0x0F, 0x07;
		}
	}

	void _onSyscallHandler(Registers* regs) {
		import syscall.action;
		import stl.io.vga;

		VMThread* thread = Scheduler.getCurrentThread();
		thread.syscallRegisters = *regs;

		with (regs)
	outer : switch (rax) {
			static foreach (module_; SyscallModules)
				static foreach (func; __traits(derivedMembers, mixin("syscall.action." ~ module_))) {
					static foreach (attr; __traits(getAttributes, mixin(func))) {
						static if (is(typeof(attr) == Syscall)) {
		case attr.id:
							pragma(msg, "_generateFunctionCall!", func, " == ", _generateFunctionCall!func);
							mixin(_generateFunctionCall!("syscall.action." ~ module_ ~ "." ~ func));
							break outer;
						}
					}
				}
		default:
			VGA.writeln("UNKNOWN SYSCALL: ", rax);
			Log.debug_("UNKNOWN SYSCALL: ", rax);
			thread.syscallRegisters.rax = ulong.max.VirtAddress;
			break;
		}
		*regs = thread.syscallRegisters;
	}
}

private template _generateFunctionCall(alias func) {
	enum ABI = ["rdi", "rsi", "rdx", "r8", "r9", "r10", "r12", "r13", "r14", "r15"];
	enum isArgument(alias attr) = is(attr == SyscallArgument!(attr.Argument));
	template gen(int count, Args...) {
		static if (count)
			enum prefix = ", ";
		else
			enum prefix = "";

		static if (Args.length == 0)
			enum gen = "";
		else static if (isArray!(Args[0].Argument)) {
			static if (count + 1 < ABI.length)
				enum gen = prefix ~ ABI[count] ~ ".array!(" ~ Args[0].ArgumentString[0 .. $ - 2] ~ ")(" ~ ABI[count + 1] ~ ")" ~ gen!(count + 2,
							Args[1 .. $]);
			else
				static assert(0, "Function " ~ func.stringof ~ " requires too many arguments!");
		} else {
			static if (count < ABI.length)
				enum gen = prefix ~ "cast(" ~ Args[0].ArgumentString ~ ")" ~ ABI[count] ~ ".num" ~ gen!(count + 1, Args[1 .. $]);
			else
				static assert(0, "Function " ~ func.stringof ~ " requires too many arguments!");
		}
	}

	enum string _generateFunctionCall = func ~ "(" ~ gen!(0, staticFilter!(isArgument, __traits(getAttributes, mixin(func)))) ~ ");";
}
