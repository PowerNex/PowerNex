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

		_startAddress = _nextFreeAddress = Linker.kernelEnd.roundUp(_maxSize);
		// TODO: Preallocate? _extend();
	}

	void[] allocate(size_t size) {
		import data.util : log2;

		size = (size + BuddyHeader.sizeof + _minSize - 1) & ~(_minSize - 1);
		if (size > _maxSize)
			return null; //TODO: Solve somehow

		ubyte factor = cast(ubyte)log2(size);
		BuddyHeader* buddy = _getFreeFactors(factor);

		if (!buddy) {
			ubyte f = factor;

			// Find hunk that is bigger than 'factor'
			while (f <= _upperFactor && !_getFreeFactors(f))
				f++;

			if (f > _upperFactor) { // Couldn't find one
				_extend();
				f--;
			}

			// Split the selected factor down to correct size

			while (f != factor) {
				BuddyHeader* oldBuddy = _getFreeFactors(f);
				_getFreeFactors(f) = oldBuddy.next;

				f--;

				oldBuddy.next = _getFreeFactors(f);
				oldBuddy.factor = f;
				//oldBuddy.magic = _magic;
				_getFreeFactors(f) = oldBuddy;

				BuddyHeader* newBuddy = (oldBuddy.VirtAddress + (1 << f)).ptr!BuddyHeader;

				newBuddy.next = _getFreeFactors(f);
				newBuddy.factor = f;
				newBuddy.magic = _magic;
				_getFreeFactors(f) = newBuddy;
			}

			// Aquire the newly created buddy
			buddy = _getFreeFactors(factor);
		}
		_getFreeFactors(factor) = buddy.next;

		return (buddy.VirtAddress + BuddyHeader.sizeof).ptr[0 .. size - BuddyHeader.sizeof];
	}

	void free(void[] address) {
		import io.log : log;

		if (address.VirtAddress < _startAddress) // Can't free memory that hasn't been allocated with KHeap, or invalid memory
			return;

		BuddyHeader* buddy = (address.VirtAddress - BuddyHeader.sizeof).ptr!BuddyHeader;
		assert(buddy.magic == _magic, "Buddy magic invalid"); // TODO: Change to a return instead of crash

		// Try and combine
		VirtAddress vBuddy = buddy;
		BuddyHeader** ptrWalker = &_getFreeFactors(buddy.factor);

		while (*ptrWalker) {
			VirtAddress vWalker = VirtAddress(*ptrWalker);
			auto familyB = (vBuddy >> buddy.factor) & ~1;
			auto familyW = (vWalker >> buddy.factor) & ~1;

			if (familyB == familyW) {
				// Found free neighbor, need to remove it from the free list
				BuddyHeader* walker = vWalker.ptr!BuddyHeader;
				*ptrWalker = walker.next;

				BuddyHeader* oldBuddy = ((vBuddy < vWalker) ? vWalker : vBuddy).ptr!BuddyHeader;
				oldBuddy.magic = [0, 0, 0]; // Invalidate old buddy

				BuddyHeader* parent = ((vBuddy < vWalker) ? vBuddy : vWalker).ptr!BuddyHeader;
				parent.factor++;

				// Restart the walk, but with the new object
				buddy = parent;
				vBuddy = buddy.VirtAddress;
				ptrWalker = &_getFreeFactors(buddy.factor);
				continue;
			}

			ptrWalker = &(*ptrWalker).next;
		}

		buddy.next = _getFreeFactors(buddy.factor);
		_getFreeFactors(buddy.factor) = buddy;
	}

	void gc() {
		// TODO: Free pages that are not longer in use, and don't have any pages that are in use after it
		// Should probably add a field to the BuddyHeader, to mark if something is free'd
		assert(0);
	}

	void print() {
		import io.log : log;

		log.info("Printing KHeap!");
		foreach (ubyte factor; _lowerFactor .. _upperFactor + 1) {
			BuddyHeader* buddy = _getFreeFactors(factor);
			if (!buddy)
				continue;

			log.info("\tFactor: ", cast(ulong)factor, " Size: ", 1 << factor);

			size_t counter;
			while (buddy) {
				log.info("\tBuddy[", counter++, "]: ", buddy);
				buddy = buddy.next;
			}
		}
		// TODO: Print out all the memory blocks
	}

private:
	enum ubyte _lowerFactor = 5; // 32B
	enum ubyte _upperFactor = 12; // 4KiB
	enum ulong _minSize = 2 ^^ _lowerFactor;
	enum ulong _maxSize = 2 ^^ _upperFactor;
	enum char[3] _magic = ['B', 'D', 'Y'];

	__gshared VirtAddress _startAddress;
	__gshared VirtAddress _nextFreeAddress;
	__gshared BuddyHeader*[_upperFactor - _lowerFactor + 1] _freeFactors;

	ref BuddyHeader* _getFreeFactors(ubyte factor) {
		return _freeFactors[factor - _lowerFactor];
	}

	void _extend() {
		import arch.paging;
		import memory.vmm : VMPageFlags;

		import io.log;

		kernelHWPaging.map(_nextFreeAddress, PhysAddress(), VMPageFlags.present | VMPageFlags.writable, false);
		BuddyHeader* newBuddy = _nextFreeAddress.ptr!BuddyHeader;
		newBuddy.next = _getFreeFactors(_upperFactor);
		newBuddy.factor = _upperFactor;
		newBuddy.magic = _magic;
		_getFreeFactors(_upperFactor) = newBuddy;

		_nextFreeAddress += 0x1000;
	}

}
