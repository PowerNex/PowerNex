module memory.allocator.wrappedallocator;

import memory.allocator;

class WrappedAllocator : IAllocator {
public:
	this(IAllocator allocator) {
		_allocator = allocator;
	}

	void[] allocate(size_t size) {
		return _allocator.allocate(size);
	}

	bool expand(ref void[] data, size_t deltaSize) {
		return _allocator.expand(data, deltaSize);
	}

	bool reallocate(ref void[] data, size_t size) {
		return _allocator.reallocate(data, size);
	}

	bool deallocate(void[] data) {
		return _allocator.deallocate(data);
	}

	bool deallocateAll() {
		return _allocator.deallocateAll();
	}

private:
	IAllocator _allocator;
}
