module memory.allocator.heapallocator;

import memory.allocator;
import memory.heap;

class HeapAllocator : IAllocator {
public:
	this(Heap heap) {
		_heap = heap;
	}

	void[] allocate(size_t size) {
		void* p = _heap.alloc(size);
		return p ? p[0 .. size] : null;
	}

	bool expand(ref void[] data, size_t deltaSize) {
		return reallocate(data, data.length + deltaSize);
	}

	bool reallocate(ref void[] data, size_t size) {
		void* p = _heap.realloc(data.ptr, size);
		if (!p)
			return false;

		data = p[0 .. size];
		return true;
	}

	bool deallocate(void[] data) {
		_heap.free(data.ptr);
		return true;
	}

	bool deallocateAll() {
		return false;
	}

private:
	Heap _heap;
}
