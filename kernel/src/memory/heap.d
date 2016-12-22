module memory.heap;

import memory.paging;
import data.linker;
import data.address;
import io.log;
import cpu.idt;
import data.register;
import task.mutex.spinlockmutex;
import data.bitfield;

private enum ulong _magic = 0xDEAD_BEEF_DEAD_C0DE;

private struct MemoryHeader {
	ulong magic;
	MemoryHeader* prev;
	MemoryHeader* next;
	private ulong data;
	mixin(bitfield!(data, "isAllocated", 1, "size", 63));
}

class Heap {
public:
	this(Paging paging, MapMode mode, VirtAddress startAddr, VirtAddress maxAddr) {
		_paging = paging;
		_mode = mode;
		_startAddr = _endAddr = startAddr;
		_maxAddr = maxAddr;
		_root = null;
		_end = null;

		_addNewPage();
		_root = _end; // 'end' will be the latest allocated page
	}

	this(Heap other) {
		assert(other);
		_paging = other._paging;
		_mode = other._mode;
		_startAddr = other._startAddr;
		_endAddr = other._endAddr;
		_maxAddr = other._maxAddr;
		_root = other._root;
		_end = other._end;
	}

	~this() {
		for (VirtAddress start = _startAddr; start < _endAddr; start += 0x1000)
			_paging.unmapAndFree(start);
	}

	void* alloc(ulong size) {
		_mutex.lock;
		if (!size)
			return null;

		MemoryHeader* freeChunk = _root;
		size += MinimalChunkSize - (size % MinimalChunkSize); // Good alignment maybe?

		while (freeChunk && (freeChunk.isAllocated || freeChunk.size < size))
			freeChunk = freeChunk.next;

		while (!freeChunk || freeChunk.size < size) { // We are currently at the end chunk
			if (!_addNewPage()) { // This will work just because there is _combine in _addNewPage, which will increase the current chunks size
				_mutex.unlock;
				return null;
			}
			freeChunk = _end; // Don't expected that freeChunk is valid, _addNewPage runs _combine
		}

		_split(freeChunk, size); // Make sure that we don't give away to much memory

		freeChunk.isAllocated = true;
		_mutex.unlock;
		return (VirtAddress(freeChunk) + MemoryHeader.sizeof).ptr;
	}

	void free(void* addr) {
		_mutex.lock;
		if (!addr)
			return;
		MemoryHeader* hdr = cast(MemoryHeader*)(VirtAddress(addr) - MemoryHeader.sizeof).ptr;
		assert(hdr.magic == _magic);
		hdr.isAllocated = false;

		_combine(hdr);

		_mutex.unlock;
	}

	void* realloc(void* addr, ulong size) {
		void* newMem = alloc(size);
		_mutex.lock;
		if (addr) {
			MemoryHeader* old = cast(MemoryHeader*)(VirtAddress(addr) - MemoryHeader.sizeof).ptr;
			assert(old.magic == _magic);
			ubyte* src = cast(ubyte*)addr;
			ubyte* dest = cast(ubyte*)newMem;
			for (ulong i = 0; i < old.size && i < size; i++)
				dest[i] = src[i];

			_mutex.unlock;
			free(addr);
		}
		return newMem;
	}

	void printLayout() {
		for (MemoryHeader* start = _root; start; start = start.next) {
			log.info("address: ", start, "\tmagic: ", cast(void*)start.magic, "\thasPrev: ", !!start.prev,
					"\thasNext: ", !!start.next, "\tisAllocated: ", !!start.isAllocated, "\tsize: ", start.size,
					"\tnext: ", start.next);

			if (start.magic != _magic)
				log.fatal("====MAGIC IS WRONG====");
		}

		log.info("\n\n");
	}

	@property ref ulong refCounter() {
		return _refCounter;
	}

private:
	enum MinimalChunkSize = 32; /// Without header

	SpinLockMutex _mutex;
	Paging _paging;
	MapMode _mode;
	MemoryHeader* _root; /// Stores the first MemoryHeader
	MemoryHeader* _end; /// Stores the last MemoryHeader
	VirtAddress _startAddr; /// The start address of all the allocated data
	VirtAddress _endAddr; /// The end address of all the allocated data
	VirtAddress _maxAddr; /// The max address that can be allocated
	ulong _refCounter;

	/// Map and add a new page to the list
	bool _addNewPage() {
		MemoryHeader* oldEnd = _end;

		if (_endAddr >= _maxAddr - 0x1000 /* Do I need this? */ )
			return false;
		if (_paging.mapFreeMemory(_endAddr, _mode).num == 0)
			return false;

		_memset64(_endAddr.ptr, 0, 0x1000 / ulong.sizeof); //Defined in object.d

		_end = cast(MemoryHeader*)_endAddr.ptr;
		*_end = MemoryHeader.init;
		_end.magic = _magic;
		_endAddr += 0x1000;

		_end.prev = oldEnd;
		if (oldEnd)
			oldEnd.next = _end;

		_end.size = 0x1000 - MemoryHeader.sizeof;
		_end.next = null;
		_end.isAllocated = false;

		_combine(_end); // Combine with other nodes if possible
		return true;
	}

	/// 'chunk' should not be expected to be valid after this
	MemoryHeader* _combine(MemoryHeader* chunk) {
		MemoryHeader* freeChunk = chunk;
		ulong sizeGain = 0;

		// Combine backwards
		while (freeChunk.prev && !freeChunk.prev.isAllocated) {
			sizeGain += freeChunk.size + MemoryHeader.sizeof;
			freeChunk = freeChunk.prev;
		}

		if (freeChunk != chunk) {
			freeChunk.size = freeChunk.size + sizeGain;
			freeChunk.next = chunk.next;
			if (freeChunk.next)
				freeChunk.next.prev = freeChunk;

			*chunk = MemoryHeader.init; // Set the old header to zero
			chunk.magic = _magic;

			chunk = freeChunk;
		}

		// Combine forwards
		sizeGain = 0;
		while (freeChunk && freeChunk.next && !freeChunk.next.isAllocated) {
			freeChunk = freeChunk.next;
			sizeGain += freeChunk.size + MemoryHeader.sizeof;
		}

		if (freeChunk != chunk) {
			chunk.size = chunk.size + sizeGain;
			chunk.next = freeChunk.next;
			if (chunk.next)
				chunk.next.prev = chunk;
		}

		if (!chunk.next)
			_end = chunk;

		return chunk;
	}

	/// It will only split if it can, chunk will always be approved to be allocated after the call this this function.
	void _split(MemoryHeader* chunk, ulong size) {
		if (chunk.size >= size + ( /* The smallest chunk size */ MemoryHeader.sizeof + MinimalChunkSize)) {
			MemoryHeader* newChunk = cast(MemoryHeader*)(VirtAddress(chunk) + MemoryHeader.sizeof + size).ptr;
			newChunk.magic = _magic;
			newChunk.prev = chunk;
			newChunk.next = chunk.next;
			chunk.next = newChunk;
			newChunk.isAllocated = false;
			newChunk.size = chunk.size - size - MemoryHeader.sizeof;
			chunk.size = size;

			if (!newChunk.next)
				_end = newChunk;
		}
	}
}

/// Get the kernel heap object
Heap getKernelHeap() {
	import data.util : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, Heap)] data;
	__gshared Heap kernelHeap;

	if (!kernelHeap) {
		kernelHeap = inplaceClass!Heap(data, getKernelPaging, MapMode.defaultUser, Linker.kernelEnd, VirtAddress(ulong.max));
		IDT.register(InterruptType.pageFault, &_onPageFault);
	}
	return kernelHeap;
}

private void _onPageFault(Registers* regs) {
	import data.textbuffer : scr = getBootTTY;
	import io.log;

	with (regs) {
		import data.color;
		import task.scheduler : getScheduler;

		auto addr = cr2;

		TablePtr!(Table!3)* tablePdp;
		TablePtr!(Table!2)* tablePd;
		TablePtr!(Table!1)* tablePt;
		TablePtr!(void)* tablePage;
		Paging _paging = getScheduler.currentProcess.threadState.paging;
		if (_paging) {
			auto _root = _paging.rootTable();
			tablePdp = _root.get(cast(ushort)(addr.num >> 39) & 0x1FF);
			if (tablePdp && tablePdp.present)
				tablePd = tablePdp.data.virtual.ptr!(Table!3).get(cast(ushort)(addr.num >> 30) & 0x1FF);
			if (tablePd && tablePd.present)
				tablePt = tablePd.data.virtual.ptr!(Table!2).get(cast(ushort)(addr.num >> 21) & 0x1FF);
			if (tablePt && tablePt.present)
				tablePage = tablePt.data.virtual.ptr!(Table!1).get(cast(ushort)(addr.num >> 12) & 0x1FF);
		}

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
		scr.writeln(" addr = ", cast(void*)addr);
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
			" addr = ",	cast(void*)addr, "\n",
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
