module memory.heap;

import memory.paging;
import linker;
import data.address;
import io.log;

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
		MemoryHeader* freeChunk = root;
		size += MinimalChunkSize - (size % MinimalChunkSize); // Good alignment maybe?

		while (freeChunk && (freeChunk.isAllocated || freeChunk.size < size))
			freeChunk = freeChunk.next;

		while (!freeChunk || freeChunk.size < size) { // We are currently at the end chunk
			addNewPage(); // This will work just because there is combine in addNewPage, which will increase the current chunks size
			freeChunk = end; // Don't expected that freeChunk is valid, addNewPage runs combine
		}

		split(freeChunk, size); // Make sure that we don't give away to much memory

		freeChunk.isAllocated = true;
		return (VirtAddress(freeChunk) + MemoryHeader.sizeof).Ptr;
	}

	void Free(void* addr) {
		MemoryHeader* hdr = cast(MemoryHeader*)(VirtAddress(addr) - MemoryHeader.sizeof).Ptr;
		hdr.isAllocated = false;
		combine(hdr);
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
	void addNewPage() {
		MemoryHeader* oldEnd = end;

		paging.MapFreeMemory(endAddr, mode);
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
		initialized = true;
	}
	return &kernelHeap;
}
