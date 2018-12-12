module syscall;

import stl.arch.amd64.idt;
import stl.arch.amd64.msr;
import stl.register;
import stl.trait;
import stl.address;
import stl.io.log;

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

struct SyscallHandler {
public static:
	void init(CPUInfo* cpuInfo) {
		import stl.spinlock;
		import stl.vmm.paging : VMPageFlags;

		__gshared SpinLock mutex;
		mutex.lock();

		setKernelStack(cpuInfo);

		MSR.star = (_kernelCS << 32UL | _userCS << 48UL);
		MSR.lStar = VirtAddress(onSyscallList[cpuInfo.id]);
		MSR.cStar = 0;
		MSR.sfMask = _eflagsInterrupt;

		MSR.gsKernel = VirtAddress(&_storage[cpuInfo.id]);

		IDT.register(0x80, cast(IDT.InterruptCallback)&_onSyscallHandler);

		import stl.arch.amd64.lapic : LAPIC;

		Log.debug_("SyscallHandler is setup for ", LAPIC.getCurrentID);
		mutex.unlock();
	}

	void setKernelStack(CPUInfo* cpuInfo) {
		_storage[cpuInfo.id].kernelStack = cpuInfo.currentThread.kernelStack;
	}

private static:
	enum ulong _userCS = 0x18 | 0x3;
	enum ulong _kernelCS = 0x8;
	enum ulong _eflagsInterrupt = 1 << 9;

	__gshared SyscallStorage[maxCPUCount] _storage;
	__gshared void function()[] onSyscallList = () {
		void function()[] ret;
		static foreach (size_t i; 0 .. maxCPUCount)
			ret ~= &_onSyscall!i;
		return ret;
	}();

	void _onSyscall(size_t id)() {
		enum kernelStack = 0;
		enum userStack = 8;

		asm pure @trusted nothrow @nogc {
			naked;
			//swapgs;
			db 0x0F, 0x01, 0xF8;

			mov GS : [userStack], RSP;
			mov RSP, GS : [kernelStack];

			// push userStack
			push GS : [userStack]; /// *userStack

			push RSP;

			push _userCS + 8; // SS
			push GS : [userStack]; // RSP
			push R11; // Flags
			push _userCS; // CS
			push RCX; // RIP

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
			//call _onSyscallHandler;
			jmp _returnFromSyscall;
		}
	}

	void _returnFromSyscall() {
		asm pure @trusted nothrow @nogc {
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

			//swapgs;
			db 0x0F, 0x01, 0xF8;
			//sysretq;
			db 0x48, 0x0F, 0x07;
		}
	}

	void _onSyscallHandler(Registers* regs) {
		import syscall.action;
		import stl.io.vga;
		import stl.arch.amd64.lapic : LAPIC;
		import stl.text : HexInt;

		VMThread* thread = Scheduler.getCurrentThread();
		//thread.inKernel = true;

		if (regs.rip < 0x10_400000) {
			size_t cpuID; // = LAPIC.getCurrentID();

			Log.info("Regs: ", regs);

			// dfmt off
		with (regs)
			Log.info("===> onSyscallHandler (CPU ", cpuID, ")", "\n",
				"IRQ = ", intNumber.num!InterruptType, " (", intNumber.HexInt, ") | RIP = ", rip, "\n",
				"RAX = ", rax, " | RBX = ", rbx, "\n",
				"RCX = ", rcx, " | RDX = ", rdx, "\n",
				"RDI = ", rdi, " | RSI = ", rsi, "\n",
				"RSP = ", rsp, " | RBP = ", rbp, "\n",
				" R8 = ", r8,  " |  R9 = ", r9, "\n",
				"R10 = ", r10, " | R11 = ", r11, "\n",
				"R12 = ", r12, " | R13 = ", r13, "\n",
				"R14 = ", r14, " | R15 = ", r15, "\n",
				" CS = ", cs,  " |  SS = ", ss, "\n",
				"CR0 = ", cr0, " | CR2 = ", cr2, "\n",
				"CR3 = ", cr3, " | CR4 = ", cr4, "\n",
				"Flags = ", flags.num.HexInt, " | Errorcode = ", errorCode.num.HexInt);
		// dfmt on
		}
		thread.syscallRegisters = *regs;

		regs.rax &= 0xFF;

		with (regs)
	outer : switch (rax) {
			static foreach (module_; SyscallModules)
				static foreach (func; __traits(derivedMembers, mixin("syscall.action." ~ module_))) {
					static foreach (attr; __traits(getAttributes, mixin(func))) {
						static if (is(typeof(attr) == Syscall)) {
		case attr.id:
							//pragma(msg, "_generateFunctionCall!", func, " == ", _generateFunctionCall!func);
							mixin(_generateFunctionCall!("syscall.action." ~ module_ ~ "." ~ func));
							break outer;
						}
					}
				}
		default:
			VGA.writeln("UNKNOWN SYSCALL: ", rax);
			Log.error("UNKNOWN SYSCALL: ", rax);
			Log.printStackTrace(rbp);
			thread.syscallRegisters.rax = ulong.max.VirtAddress;
			break;
		}
		*regs = thread.syscallRegisters;

		//thread.inKernel = false;
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
		else static if (is(Unqual!(Args[0].Argument) : E[], E)) {
			static if (count + 1 < ABI.length)
				enum gen = prefix ~ ABI[count] ~ ".array!(" ~ E.stringof ~ ")(" ~ ABI[count + 1] ~ ")" ~ gen!(count + 2, Args[1 .. $]);
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
