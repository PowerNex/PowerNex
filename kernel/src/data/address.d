module data.address;

private mixin template AddressBase() {
	void* addr;

	alias addr this;

	this(void* addr) {
		this.addr = addr;
	}

	this(ulong addr) {
		this.addr = cast(void*)addr;
	}

	ref typeof(this) opBinary(string op)(void* other) {
		mixin("addr = cast(void*)(cast(ulong)addr" ~ op ~ "cast(ulong)other);");
		return this;
	}

	ref typeof(this) opBinary(string op)(ulong other) {
		mixin("addr = cast(void*)(cast(ulong)addr" ~ op ~ "other);");
		return this;
	}

	ref typeof(this) opBinary(string op)(typeof(this) other) {
		return opBinary!op(other.Ptr);
	}

	int opCmp(typeof(this) other) const {
		if (Int < other.Int)
			return -1;
		else if (Int > other.Int)
			return 1;
		else
			return 0;
	}

	int opCmp(ulong other) const {
		if (Int < other)
			return -1;
		else if (Int > other)
			return 1;
		else
			return 0;
	}

	@property T* Ptr(T = void)() {
		return cast(T*)addr;
	}

	@property ulong Int() const {
		return cast(ulong)addr;
	}
}

struct VirtAddress {
	mixin AddressBase;
}

struct PhysAddress {
	mixin AddressBase;

	@property VirtAddress Virtual() const {
		return VirtAddress(Int + 0xFFFF_8000_0000_0000);
	}
}

static assert(VirtAddress.sizeof == size_t.sizeof);
static assert(PhysAddress.sizeof == size_t.sizeof);
