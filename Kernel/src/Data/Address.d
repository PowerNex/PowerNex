module Data.Address;

private mixin template AddressBase() {
	ulong addr;

	alias addr this;

	this(void* addr) {
		this.addr = cast(ulong)addr;
	}

	this(ulong addr) {
		this.addr = addr;
	}

	typeof(this) opBinary(string op)(void* other) const {
		return typeof(this)(mixin("addr" ~ op ~ "cast(ulong)other"));
	}

	typeof(this) opBinary(string op)(ulong other) const {
		return typeof(this)(mixin("addr" ~ op ~ "other"));
	}

	typeof(this) opBinary(string op)(typeof(this) other) const {
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

	@property T* Ptr(T = void)(T addr) {
		this.addr = cast(ulong)addr;
		return cast(T*)addr;
	}


	@property ulong Int() const {
		return addr;
	}

	@property ulong Int(ulong addr) {
		this.addr = addr;
		return addr;
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
