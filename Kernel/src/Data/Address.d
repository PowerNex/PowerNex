module Data.Address;

private mixin template AddressBase(Type = ulong) {
	Type addr;

	alias addr this;

	this(void* addr) {
		this.addr = cast(Type)addr;
	}

	this(Type addr) {
		this.addr = addr;
	}

	typeof(this) opBinary(string op)(void* other) const {
		return typeof(this)(mixin("addr" ~ op ~ "cast(Type)other"));
	}

	typeof(this) opBinary(string op)(Type other) const {
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

	int opCmp(Type other) const {
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
		this.addr = cast(Type)addr;
		return cast(T*)addr;
	}

	@property Type Int() const {
		return addr;
	}

	@property Type Int(Type addr) {
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

struct PhysAddress32 {
	mixin AddressBase!uint;

	@property VirtAddress Virtual() const {
		return VirtAddress(Int + 0xFFFF_8000_0000_0000);
	}
}

static assert(VirtAddress.sizeof == size_t.sizeof);
static assert(PhysAddress.sizeof == size_t.sizeof);
static assert(PhysAddress32.sizeof == uint.sizeof);
