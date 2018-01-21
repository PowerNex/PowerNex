module memory.allocator.kheapallocator;

import memory.allocator;
import io.log;
import memory.kheap;

class KHeapAllocator : IAllocator {
public:
	void[] allocate(size_t size) {
		void[] mem = KHeap.allocate(size);
		if (mem)
			mem = mem[0 .. size];
		return mem;
	}

	bool expand(ref void[] data, size_t deltaSize) {
		return false;
	}

	bool reallocate(ref void[] data, size_t size) {
		void[] newData = allocate(size);
		if (!newData)
			return false;

		if (data.length < size)
			newData[0 .. data.length] = data[];
		else
			newData[] = data[0 .. size];

		deallocate(data);

		data = newData;
		return true;
	}

	bool deallocate(void[] data) {
		KHeap.free(data);
		return true;
	}

	bool deallocateAll() {
		return false;
	}

private:
}
