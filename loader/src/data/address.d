/**
 * Helper data structures for abstracing memory addresses.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module data.address;

//XXX: Functions that cast SHOULD NOT be @safe/@trusted, as this invalidates the whole safeness system
// It is currently like this because of lazyness

pragma(inline, true):
private mixin template AddressBase(Type = size_t) {
	alias Func = void function(); ///
	Type addr; ///

	alias addr this; ///

	///
	this(void* addr) {
		this.addr = cast(Type)addr;
	}

	///
	this(Type addr) {
		this.addr = addr;
	}

	///
	this(Func func) {
		this.addr = cast(Type)func;
	}

	///
	this(T)(T[] arr) {
		this.addr = cast(Type)arr.ptr;
	}

	static if (is(Type == size_t)) {
		/// Only for power of two
		typeof(this) roundUp(size_t multiplier) {
			assert(multiplier && (multiplier & (multiplier - 1)) == 0, "Not power of two!");
			return typeof(this)((addr + multiplier - 1) & ~(multiplier - 1));
		}
	}

	///
	typeof(this) opBinary(string op)(void* other) const {
		return typeof(this)(mixin("addr" ~ op ~ "cast(Type)other"));
	}

	///
	typeof(this) opBinary(string op)(Type other) const {
		return typeof(this)(mixin("addr" ~ op ~ "other"));
	}

	///
	typeof(this) opBinary(string op)(typeof(this) other) const {
		return opBinary!op(other.ptr);
	}

	///
	typeof(this) opOpAssign(string op)(void* other) {
		return typeof(this)(mixin("addr" ~ op ~ "= cast(Type)other"));
	}

	///
	typeof(this) opOpAssign(string op)(Type other) {
		return typeof(this)(mixin("addr" ~ op ~ "= other"));
	}

	///
	typeof(this) opOpAssign(string op)(typeof(this) other) {
		return opOpAssign!op(other.ptr);
	}

	///
	int opCmp(ref const typeof(this) other) const {
		if (num < other.num)
			return -1;
		else if (num > other.num)
			return 1;
		else
			return 0;
	}

	///
	int opCmp(Type other) const {
		if (num < other)
			return -1;
		else if (num > other)
			return 1;
		else
			return 0;
	}

	///
	@property T* ptr(T = void)() @trusted {
		return cast(T*)addr;
	}

	///
	@property T* ptr(T = void)() @trusted const {
		return cast(T*)addr;
	}

	///
	@property T* ptr(T = void)(T addr) {
		this.addr = cast(Type)addr;
		return cast(T*)addr;
	}

	///
	@property Type num() const {
		return addr;
	}

	///
	@property Type num(Type addr) {
		this.addr = addr;
		return addr;
	}

	///
	@property Func func() const @trusted {
		return cast(Func)addr;
	}

	///
	@property Func func(Func func) @trusted {
		this.addr = cast(Type)func;
		return cast(Func)addr;
	}

	///
	T array(T : X[], X)(size_t length) const {
		return (cast(X*)addr)[0 .. length];
	}

	///
	@property T array(T)(T array_) {
		this.addr = cast(Type)array_.ptr;
		return array_;
	}
}

/// This represents a virtual address
@safe struct VirtAddress {
	mixin AddressBase;

	///
	VirtAddress memcpy(VirtAddress other, size_t size) @trusted {
		ptr!ubyte[0 .. size] = other.ptr!ubyte[0 .. size];

		return this;
	}

	///
	VirtAddress memset(ubyte val, size_t size) @trusted {
		//TODO: optimize
		foreach (ref b; ptr!ubyte[0 .. size])
			b = val;

		return this;
	}
}

/// This represents a physical address
@safe struct PhysAddress {
	mixin AddressBase;

	/// WARNING: THIS FUNCTION WILL NOT ALWAYS WORK
	VirtAddress toVirtual() {
		return VirtAddress(addr);
	}
}

/// This represents a 32-bit physical address
@safe struct PhysAddress32 {
	mixin AddressBase!uint;

	///
	@property PhysAddress toX64() {
		return addr.PhysAddress;
	}
}

static assert(VirtAddress.sizeof == size_t.sizeof);
static assert(PhysAddress.sizeof == size_t.sizeof);
static assert(PhysAddress32.sizeof == uint.sizeof);
