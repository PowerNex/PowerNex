module data.address;

private mixin template AddressBase(Type = size_t) {
	alias Func = void function();
	Type addr;

	alias addr this;

	this(void* addr) {
		this.addr = cast(Type)addr;
	}

	this(Type addr) {
		this.addr = addr;
	}

	this(Func func) {
		this.addr = cast(Type)func;
	}

	this(T)(T[] arr) {
		this.addr = cast(Type)arr.ptr;
	}

	typeof(this) opBinary(string op)(void* other) const {
		return typeof(this)(mixin("addr" ~ op ~ "cast(Type)other"));
	}

	typeof(this) opBinary(string op)(Type other) const {
		return typeof(this)(mixin("addr" ~ op ~ "other"));
	}

	typeof(this) opBinary(string op)(typeof(this) other) const {
		return opBinary!op(other.ptr);
	}

	typeof(this) opOpAssign(string op)(void* other) {
		return typeof(this)(mixin("addr" ~ op ~ "= cast(Type)other"));
	}

	typeof(this) opOpAssign(string op)(Type other) {
		return typeof(this)(mixin("addr" ~ op ~ "= other"));
	}

	typeof(this) opOpAssign(string op)(typeof(this) other) {
		return opOpAssign!op(other.ptr);
	}

	int opCmp(typeof(this) other) const {
		if (num < other.num)
			return -1;
		else if (num > other.num)
			return 1;
		else
			return 0;
	}

	int opCmp(Type other) const {
		if (num < other)
			return -1;
		else if (num > other)
			return 1;
		else
			return 0;
	}

	@property T* ptr(T = void)() {
		return cast(T*)addr;
	}

	@property T* ptr(T = void)(T addr) {
		this.addr = cast(Type)addr;
		return cast(T*)addr;
	}

	@property Type num() const {
		return addr;
	}

	@property Type num(Type addr) {
		this.addr = addr;
		return addr;
	}

	@property Func func() const {
		return cast(Func)addr;
	}

	@property Func func(Func func) {
		this.addr = cast(Type)func;
		return cast(Func)addr;
	}

	T array(T : X[], X)(size_t length) const {
		return (cast(X*)addr)[0 .. length];
	}

	@property T array(T)(T array_) {
		this.addr = cast(Type)array_.ptr;
		return array_;
	}
}

struct VirtAddress {
	mixin AddressBase;
}

struct PhysAddress {
	mixin AddressBase;

	deprecated("PhysAddress -> VirtAddress must always go though the VMM") @property VirtAddress virtual() const {
		return VirtAddress(addr + 0xFFFF_8000_0000_0000);
	}
}

struct PhysAddress32 {
	mixin AddressBase!uint;

	deprecated("PhysAddress -> VirtAddress must always go though the VMM") @property VirtAddress virtual() const {
		return VirtAddress(addr + 0xFFFF_8000_0000_0000);
	}
}

static assert(VirtAddress.sizeof == size_t.sizeof);
static assert(PhysAddress.sizeof == size_t.sizeof);
static assert(PhysAddress32.sizeof == uint.sizeof);
