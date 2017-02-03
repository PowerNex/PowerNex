module memory.allocator.userspaceallocator;

import data.address;
import memory.allocator;
import memory.allocator.heapallocator;
import memory.ref_;
import memory.heap;
import task.process;
import memory.paging;

class UserSpaceAllocator : HeapAllocator {
public:
	this(Ref!Process process, VirtAddress startHeap) {
		_heap = kernelAllocator.makeRef!Heap((*process).threadState.paging, MapMode.defaultUser, startHeap, VirtAddress(0xFFFF_FFFF_0000_0000));
		super(_heap.data);
	}

	this(UserSpaceAllocator other) {
		assert(other);
		_heap = kernelAllocator.makeRef!Heap(other._heap.data);
		super(_heap.data);
	}

private:
	Ref!Heap _heap;
}
