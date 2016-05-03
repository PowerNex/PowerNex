module Memory.Heap;

import Memory.Paging;
import Data.Linker;
import Data.Address;
import IO.Log;
import CPU.IDT;
import Data.Register;

private struct MemoryHeader {
	MemoryHeader* prev;
	MemoryHeader* next;
	ulong isAllocated; // could be bool, but for padding reasons it's a ulong
	ulong size;
}

struct Heap {
public:
	 ~this() {
		for (VirtAddress start = startAddr; start < endAddr; start += 0x1000)
			paging.UnmapAndFree(start);
	}

	void Init(Paging* paging, MapMode mode, VirtAddress startAddr) {
		this.paging = paging;
		this.mode = mode;
		this.startAddr = this.endAddr = startAddr;
		this.root = null;
		this.end = null;

		addNewPage();
		root = end; // 'end' will be the latest allocated page
	}

	void* Alloc(ulong size) {
		if (!size)
			return null;
		MemoryHeader* freeChunk = root;
		size += MinimalChunkSize - (size % MinimalChunkSize); // Good alignment maybe?

		while (freeChunk && (freeChunk.isAllocated || freeChunk.size < size))
			freeChunk = freeChunk.next;

		while (!freeChunk || freeChunk.size < size) { // We are currently at the end chunk
			if (!addNewPage()) // This will work just because there is combine in addNewPage, which will increase the current chunks size
				return null;
			freeChunk = end; // Don't expected that freeChunk is valid, addNewPage runs combine
		}

		split(freeChunk, size); // Make sure that we don't give away to much memory

		freeChunk.isAllocated = true;
		return (VirtAddress(freeChunk) + MemoryHeader.sizeof).Ptr;
	}

	void Free(void* addr) {
		if (!addr)
			return;
		MemoryHeader* hdr = cast(MemoryHeader*)(VirtAddress(addr) - MemoryHeader.sizeof).Ptr;
		hdr.isAllocated = false;
		combine(hdr);
	}

	void* Realloc(void* addr, ulong size) {
		void* newMem = Alloc(size);
		if (addr) {
			MemoryHeader* old = cast(MemoryHeader*)(VirtAddress(addr) - MemoryHeader.sizeof).Ptr;
			ubyte* src = cast(ubyte*)addr;
			ubyte* dest = cast(ubyte*)newMem;
			for (ulong i = 0; i < old.size && i < size; i++)
				dest[i] = src[i];
			Free(addr);
		}
		return newMem;
	}

	void PrintLayout() {
		for (MemoryHeader* start = root; start; start = start.next)
			log.Info("address: ", start, "\thasPrev: ", !!start.prev, "\thasNext: ", !!start.next,
					"\tisAllocated: ", !!start.isAllocated, "\tsize: ", start.size);

		log.Info("\n\n");
	}

private:
	enum MinimalChunkSize = 32; /// Without header

	Paging* paging;
	MapMode mode;
	MemoryHeader* root; /// Stores the first MemoryHeader
	MemoryHeader* end; /// Stores the last MemoryHeader
	VirtAddress startAddr; /// The start address of all the allocated data
	VirtAddress endAddr; /// The end address of all the allocated data

	/// Map and add a new page to the list
	bool addNewPage() {
		MemoryHeader* oldEnd = end;

		if (paging.MapFreeMemory(endAddr, mode).Int == 0)
			return false;
		end = cast(MemoryHeader*)endAddr.Ptr;
		*end = MemoryHeader.init;
		endAddr += 0x1000;

		end.prev = oldEnd;
		if (oldEnd)
			oldEnd.next = end;

		end.size = 0x1000 - MemoryHeader.sizeof;
		end.next = null;
		end.isAllocated = false;

		combine(end); // Combine with other nodes if possible
		return true;
	}

	/// 'chunk' should not be expected to be valid after this
	MemoryHeader* combine(MemoryHeader* chunk) {
		MemoryHeader* freeChunk = chunk;
		ulong sizeGain = 0;

		// Combine backwards
		while (freeChunk.prev && !freeChunk.prev.isAllocated) {
			sizeGain += freeChunk.size + MemoryHeader.sizeof;
			freeChunk = freeChunk.prev;
		}

		if (freeChunk != chunk) {
			freeChunk.size += sizeGain;
			freeChunk.next = chunk.next;
			if (freeChunk.next)
				freeChunk.next.prev = freeChunk;

			*chunk = MemoryHeader.init; // Set the old header to zero

			chunk = freeChunk;
		}

		// Combine forwards
		sizeGain = 0;
		while (freeChunk.next && !freeChunk.next.isAllocated) {
			freeChunk = freeChunk.next;
			sizeGain += freeChunk.size + MemoryHeader.sizeof;
		}

		if (freeChunk != chunk) {
			chunk.size += sizeGain;
			chunk.next = freeChunk.next;
			if (chunk.next)
				chunk.next.prev = chunk;
		}

		if (!chunk.next)
			end = chunk;

		return chunk;
	}

	/// It will only split if it can, chunk will always be approved to be allocated after the call this this function.
	void split(MemoryHeader* chunk, ulong size) {
		if (chunk.size >= size + ( /* The smallest chunk size */ MemoryHeader.sizeof + MinimalChunkSize)) {
			MemoryHeader* newChunk = cast(MemoryHeader*)(VirtAddress(chunk) + MemoryHeader.sizeof + size).Ptr;
			newChunk.prev = chunk;
			newChunk.next = chunk.next;
			chunk.next = newChunk;
			newChunk.isAllocated = false;
			newChunk.size = chunk.size - size - MemoryHeader.sizeof;
			chunk.size = size;

			if (!newChunk.next)
				end = newChunk;
		}
	}
}

/// Get the kernel heap object
Heap* GetKernelHeap() {
	__gshared Heap kernelHeap;
	__gshared bool initialized = false;

	if (!initialized) {
		kernelHeap.Init(GetKernelPaging, MapMode.DefaultKernel, Linker.KernelEnd);
		IDT.Register(InterruptType.PageFault, &onPageFault);
		initialized = true;
	}
	return &kernelHeap;
}

private void onPageFault(Registers* regs) {
	import IO.TextMode;
	import IO.Log;

	alias scr = GetScreen;
	with (regs) {
		if (IntNumber == InterruptType.PageFault) {
			scr.Writeln("===> PAGE FAULT");
			scr.Writeln("IRQ = ", IntNumber, " | RIP = ", cast(void*)RIP);
			scr.Writeln("RAX = ", cast(void*)RAX, " | RBX = ", cast(void*)RBX);
			scr.Writeln("RCX = ", cast(void*)RCX, " | RDX = ", cast(void*)RDX);
			scr.Writeln("RDI = ", cast(void*)RDI, " | RSI = ", cast(void*)RSI);
			scr.Writeln("RSP = ", cast(void*)RSP, " | RBP = ", cast(void*)RBP);
			scr.Writeln(" R8 = ", cast(void*)R8, "  |  R9 = ", cast(void*)R9);
			scr.Writeln("R10 = ", cast(void*)R10, " | R11 = ", cast(void*)R11);
			scr.Writeln("R12 = ", cast(void*)R12, " | R13 = ", cast(void*)R13);
			scr.Writeln("R14 = ", cast(void*)R14, " | R15 = ", cast(void*)R15);
			scr.Writeln(" CS = ", cast(void*)CS, "  |  SS = ", cast(void*)SS);
			scr.Writeln(" CR2 = ", cast(void*)CR2);
			scr.Writeln("Flags: ", cast(void*)Flags);
			scr.Writeln("Errorcode: ", cast(void*)ErrorCode);
		} else
			scr.Writeln("INTERRUPT: ", cast(InterruptType)IntNumber, " Errorcode: ", ErrorCode);

		if (IntNumber == InterruptType.PageFault) {
			log.Fatal("===> PAGE FAULT", "\n", "IRQ = ", IntNumber, " | RIP = ", cast(void*)RIP, "\n", "RAX = ",
					cast(void*)RAX, " | RBX = ", cast(void*)RBX, "\n", "RCX = ", cast(void*)RCX, " | RDX = ",
					cast(void*)RDX, "\n", "RDI = ", cast(void*)RDI, " | RSI = ", cast(void*)RSI, "\n", "RSP = ",
					cast(void*)RSP, " | RBP = ", cast(void*)RBP, "\n", " R8 = ", cast(void*)R8, "  |  R9 = ",
					cast(void*)R9, "\n", "R10 = ", cast(void*)R10, " | R11 = ", cast(void*)R11, "\n", "R12 = ",
					cast(void*)R12, " | R13 = ", cast(void*)R13, "\n", "R14 = ", cast(void*)R14, " | R15 = ",
					cast(void*)R15, "\n", " CS = ", cast(void*)CS, "  |  SS = ", cast(void*)SS, "\n", " CR2 = ",
					cast(void*)CR2, "\n", "Flags: ", cast(void*)Flags, "\n", "Errorcode: ", cast(void*)ErrorCode);
		} else
			log.Fatal("Interrupt!\r\n", "\tIntNumber: ", cast(void*)IntNumber, " ErrorCode: ", cast(void*)ErrorCode,
					"\r\n", "\tRAX: ", cast(void*)RAX, " RBX: ", cast(void*)RBX, " RCX: ", cast(void*)RCX, " RDX: ",
					cast(void*)RDX, "\r\n", "\tRSI: ", cast(void*)RSI, " RDI: ", cast(void*)RDI, " RBP: ",
					cast(void*)RBP, "\r\n", "\tRIP: ", cast(void*)RIP, " RSP: ", cast(void*)RSP, " Flags: ",
					cast(void*)Flags, " SS: ", cast(void*)SS, " CS: ", cast(void*)CS,);
	}
}
