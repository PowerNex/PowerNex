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

	@property void* Ptr() {
		return addr;
	}

	@property ulong Int() {
		return cast(ulong)addr;
	}
}

struct VirtAddress {
	mixin AddressBase;
}

struct PhysAddress {
	mixin AddressBase;
}

static assert(VirtAddress.sizeof == size_t.sizeof);
static assert(PhysAddress.sizeof == size_t.sizeof);
