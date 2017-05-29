module memory.kheap;

struct BuddyHeader {
	BuddyHeader* next;
	ubyte factor;
	char[3] magic;
}

static assert(BuddyHeader.sizeof == 2 * ulong.sizeof);

struct KHeap {
	import data.address;

static:
public:
	void init() {
		import data.linker : Linker;

		_nextFreeAddress = Linker.kernelEnd.roundUp(0x1000);
		_extend();
	}

	void[] allocate(size_t size) {
		import data.util : log2;

		size = (size + BuddyHeader.sizeof + 0x1F) & ~(0x1F);
		int factor = log2(size);
		BuddyHeader* buddy = _getFreeFactors(factor);
		if (!buddy) {
			//TODO: Split
		}
		_getFreeFactors(factor) = buddy.next;

		return (buddy.VirtAddress + BuddyHeader.sizeof).ptr[0 .. size - BuddyHeader.sizeof];
	}

	void free(void[] address) {
		BuddyHeader* buddy = (address.VirtAddress - BuddyHeader.sizeof).ptr!BuddyHeader;
		assert(buddy.magic == _magic, "Buddy magic invalid");

		buddy.next = _getFreeFactors(buddy.factor);
		_getFreeFactors(buddy.factor) = buddy;

		//TODO: combine?
	}

private:
	enum _lowerFactor = 5; // 32bytes
	enum _upperFactor = 12; // 4Kibi
	enum char[3] _magic = ['B', 'D', 'Y'];

	__gshared VirtAddress _nextFreeAddress;
	__gshared BuddyHeader*[_upperFactor - _lowerFactor + 1] _freeFactors;

	ref BuddyHeader* _getFreeFactors(ushort factor) {
		return _freeFactors[factor - _lowerFactor];
	}

	void _extend() {
		import arch.paging;

		kernelHWPaging.map(_nextFreeAddress, PhysAddress(), VMPageFlags.present | VMPageFlags.writable, false);
		BuddyHeader* newBuddy = _nextFreeAddress.ptr!BuddyHeader;
		newBuddy.next = _getFreeFactors(_upperFactor);
		newBuddy.factor = _upperFactor;
		newBuddy.magic[] = _magic;
		_getFreeFactors(_upperFactor) = newBuddy;
	}

}

// IDT.register(InterruptType.pageFault, &_onPageFault);
/+private void _onPageFault(from!"data.register".Registers* regs) {
	import data.textbuffer : scr = getBootTTY;
	import io.log;

	with (regs) {
		import data.color;

		auto addr = cr2;

		/*ablePtr!(Table!3)* tablePdp;
		TablePtr!(Table!2)* tablePd;
		TablePtr!(Table!1)* tablePt;
		TablePtr!(void)* tablePage;
		//Paging paging;
		{
			import task.scheduler : getScheduler;
			auto s = getScheduler;
			if (s) {
				auto cp = s.currentProcess;
				if (cp)
					paging = (*cp).threadState.paging;
			}
		}
		if (paging) {
			auto _root = paging.rootTable();
			tablePdp = _root.get(cast(ushort)(addr.num >> 39) & 0x1FF);
			if (tablePdp && tablePdp.present)
				tablePd = tablePdp.data.virtual.ptr!(Table!3).get(cast(ushort)(addr.num >> 30) & 0x1FF);
			if (tablePd && tablePd.present)
				tablePt = tablePd.data.virtual.ptr!(Table!2).get(cast(ushort)(addr.num >> 21) & 0x1FF);
			if (tablePt && tablePt.present)
				tablePage = tablePt.data.virtual.ptr!(Table!1).get(cast(ushort)(addr.num >> 12) & 0x1FF);
		}*/

		MapMode modePdp;
		MapMode modePd;
		MapMode modePt;
		MapMode modePage;
		if (tablePdp)
			modePdp = tablePdp.mode;
		if (tablePd)
			modePd = tablePd.mode;
		if (tablePt)
			modePt = tablePt.mode;
		if (tablePage)
			modePage = tablePage.mode;

		ulong cr3 = cpuRetCR3();

		scr.foreground = Color(255, 0, 0);
		scr.writeln("===> PAGE FAULT");
		scr.writeln("IRQ = ", intNumber, " | RIP = ", cast(void*)rip);
		scr.writeln("RAX = ", cast(void*)rax, " | RBX = ", cast(void*)rbx);
		scr.writeln("RCX = ", cast(void*)rcx, " | RDX = ", cast(void*)rdx);
		scr.writeln("RDI = ", cast(void*)rdi, " | RSI = ", cast(void*)rsi);
		scr.writeln("RSP = ", cast(void*)rsp, " | RBP = ", cast(void*)rbp);
		scr.writeln(" R8 = ", cast(void*)r8, "  |  R9 = ", cast(void*)r9);
		scr.writeln("R10 = ", cast(void*)r10, " | R11 = ", cast(void*)r11);
		scr.writeln("R12 = ", cast(void*)r12, " | R13 = ", cast(void*)r13);
		scr.writeln("R14 = ", cast(void*)r14, " | R15 = ", cast(void*)r15);
		scr.writeln(" CS = ", cast(void*)cs, "  |  SS = ", cast(void*)ss);
		scr.writeln(" addr = ", cast(void*)addr, " | CR3 = ", cast(void*)cr3);
		scr.writeln("Flags: ", cast(void*)flags);
		scr.writeln("Errorcode: ", cast(void*)errorCode, " (", (errorCode & (1 << 0) ? " Present" : " NotPresent"),
				(errorCode & (1 << 1) ? " Write" : " Read"), (errorCode & (1 << 2) ? " UserMode" : " KernelMode"),
				(errorCode & (1 << 3) ? " ReservedWrite" : ""), (errorCode & (1 << 4) ? " InstructionFetch" : ""), " )");
		scr.writeln("PDP Mode: ", (tablePdp && tablePdp.present) ? "R" : "", (modePdp & MapMode.writable) ? "W" : "",
				(modePdp & MapMode.noExecute) ? "" : "X", (modePdp & MapMode.user) ? "-User" : "");
		scr.writeln("PD Mode: ", (tablePd && tablePd.present) ? "R" : "", (modePd & MapMode.writable) ? "W" : "",
				(modePd & MapMode.noExecute) ? "" : "X", (modePd & MapMode.user) ? "-User" : "");
		scr.writeln("PT Mode: ", (tablePt && tablePt.present) ? "R" : "", (modePt & MapMode.writable) ? "W" : "",
				(modePt & MapMode.noExecute) ? "" : "X", (modePt & MapMode.user) ? "-User" : "");
		scr.writeln("Page Mode: ", (tablePage && tablePage.present) ? "R" : "", (modePage & MapMode.writable) ? "W" : "",
				(modePage & MapMode.noExecute) ? "" : "X", (modePage & MapMode.user) ? "-User" : "");

		//dfmt off
		log.fatal("===> PAGE FAULT", "\n", "IRQ = ", intNumber, " | RIP = ", cast(void*)rip, "\n",
			"RAX = ", cast(void*)rax, " | RBX = ", cast(void*)rbx, "\n",
			"RCX = ", cast(void*)rcx, " | RDX = ", cast(void*)rdx, "\n",
			"RDI = ", cast(void*)rdi, " | RSI = ", cast(void*)rsi, "\n",
			"RSP = ", cast(void*)rsp, " | RBP = ", cast(void*)rbp, "\n",
			" R8 = ", cast(void*)r8, "  |  R9 = ", cast(void*)r9, "\n",
			"R10 = ", cast(void*)r10, " | R11 = ", cast(void*)r11, "\n",
			"R12 = ", cast(void*)r12, " | R13 = ", cast(void*)r13, "\n",
			"R14 = ", cast(void*)r14, " | R15 = ", cast(void*)r15, "\n",
			" CS = ", cast(void*)cs, "  |  SS = ", cast(void*)ss, "\n",
			" addr = ",	cast(void*)addr, " | CR3 = ", cast(void*)cr3, "\n",
			"Flags: ", cast(void*)flags, "\n",
			"Errorcode: ", cast(void*)errorCode, " (",
				(errorCode & (1 << 0) ? " Present" : " NotPresent"),
				(errorCode & (1 << 1) ? " Write" : " Read"),
				(errorCode & (1 << 2) ? " UserMode" : " KernelMode"),
				(errorCode & (1 << 3) ? " ReservedWrite" : ""),
				(errorCode & (1 << 4) ? " InstructionFetch" : ""),
			" )", "\n",
			"PDP Mode: ",
				(tablePdp && tablePdp.present) ? "R" : "",
				(modePdp & MapMode.writable) ? "W" : "",
				(modePdp & MapMode.noExecute) ? "" : "X",
				(modePdp & MapMode.user) ? "-User" : "", "\n",
			"PD Mode: ",
				(tablePd && tablePd.present) ? "R" : "",
				(modePd & MapMode.writable) ? "W" : "",
				(modePd & MapMode.noExecute) ? "" : "X",
				(modePd & MapMode.user) ? "-User" : "", "\n",
			"PT Mode: ",
				(tablePt && tablePt.present) ? "R" : "",
				(modePt & MapMode.writable) ? "W" : "",
				(modePt & MapMode.noExecute) ? "" : "X",
				(modePt & MapMode.user) ? "-User" : "", "\n",
			"Page Mode: ",
				(tablePage && tablePage.present) ? "R" : "",
				(modePage & MapMode.writable) ? "W" : "",
				(modePage & MapMode.noExecute) ? "" : "X",
				(modePage & MapMode.user) ? "-User" : "");
		//dfmt on
	}
}
+/
