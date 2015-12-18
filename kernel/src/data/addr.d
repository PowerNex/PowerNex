module data.addr;

private mixin template AddrBase() {
	void* addr;

	alias addr this;

	this(void* addr) {
		this.addr = addr;
	}

	this(ulong addr) {
		this.addr = cast(void*)addr;
	}

	@property void* toPtr() {
		return addr;
	}

	@property ulong toInt() {
		return cast(ulong)addr;
	}
}

struct VAddr {
	mixin AddrBase;
}

struct PAddr {
	mixin AddrBase;
}

static assert(VAddr.sizeof == size_t.sizeof);
static assert(PAddr.sizeof == size_t.sizeof);
