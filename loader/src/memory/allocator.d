module memory.allocator;

import data.address;

private extern extern (C) __gshared ubyte LOADER_END;

@safe static struct Allocator {
public static:
	void init(VirtAddress end) @trusted {
		this.end = end;
	}

	VirtAddress alloc(size_t size, size_t alignment) @trusted {
		end = end.roundUp(alignment);
		VirtAddress addr = end;
		end += size;
		return addr;
	}

private static:
	__gshared VirtAddress end;
}
