module memory.allocator.staticallocator;

import memory.allocator;
import io.log;

/**
 * This is a super early boot time allocator.
 * This is to be used for when the paging and other stuff needed stuff have been initialized
 * It will not support any deallocation, It will lie and return that is has freed the memory but this is not true.
 * Use this only if you have to allocate somethingy dynamically, else wait for then the real allocator is up and running.
 */
class StaticAllocator : IAllocator {
public:
	this(ubyte[] data) {
		_data = data;
	}

	void[] allocate(size_t size) {
		import io.log;

		if (_pos + size >= _data.length)
			log.fatal(_pos + size, " >= ", _data.length);

		void[] data = _data[_pos .. _pos + size];
		_pos += size;
		log.info("Allocated ", size, " @ ", data.ptr);
		return data;
	}

	bool expand(ref void[] data, size_t deltaSize) {
		return false;
	}

	bool reallocate(ref void[] data, size_t size) {
		void[] newData = allocate(size);
		if (!newData)
			return false;

		log.info("Reallocated ", size, " @ ", newData.ptr, " oldData is ", data.length, " @ ", data.ptr);

		newData[0 .. data.length] = data[];

		data = newData[0 .. size];
		return true;
	}

	bool deallocate(void[] data) {
		log.info("Freed ", data.length, " @ ", data.ptr);
		return true; // Big fat lie
	}

	bool deallocateAll() {
		return false;
	}

private:
	ubyte[] _data;
	ulong _pos;
}
