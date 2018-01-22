/**
 * Helper data structures for abstracing memory addresses.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.address;

//XXX: Functions that cast SHOULD NOT be @safe/@trusted, as this invalidates the whole safeness system
// It is currently like this because of lazyness

pragma(inline, true):
private mixin template AddressBase(Type = size_t) {
	alias Self = typeof(this);
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
	this(Func)(Func func) if (is(Func == function)) {
		this.addr = cast(Type)func;
	}

	///
	this(T)(T[] arr) {
		this.addr = cast(Type)arr.ptr;
	}

	static if (is(Type == size_t)) {
		/// Only for power of two
		Self roundUp(size_t multiplier) {
			assert(multiplier && (multiplier & (multiplier - 1)) == 0, "Not power of two!");
			return Self((addr + multiplier - 1) & ~(multiplier - 1));
		}
	}

	///
	Self opBinary(string op)(void* other) const {
		return Self(mixin("addr" ~ op ~ "cast(Type)other"));
	}

	///
	Self opBinary(string op)(Type other) const {
		return Self(mixin("addr" ~ op ~ "other"));
	}

	///
	Self opBinary(string op)(Self other) const {
		return opBinary!op(other.num);
	}

	///
	Self opOpAssign(string op)(void* other) {
		return Self(mixin("addr" ~ op ~ "= cast(Type)other"));
	}

	///
	Self opOpAssign(string op)(Type other) {
		return Self(mixin("addr" ~ op ~ "= other"));
	}

	///
	Self opOpAssign(string op)(Self other) {
		return opOpAssign!op(other.ptr);
	}

	///
	int opCmp(ref const Self other) const {
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
	@property T* ptr(T = void)(T addr) {
		this.addr = cast(Type)addr;
		return cast(T*)addr;
	}

	///
	@property T num(T = Type)() const {
		return cast(T)addr;
	}

	///
	@property Type num(Type addr) {
		this.addr = addr;
		return addr;
	}

	///
	@property Func func(Func)(Func func) @trusted if (is(Func == function)) {
		this.addr = cast(Type)func;
		return cast(Func)addr;
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
	@property T* ptr(T = void)() @trusted {
		return cast(T*)addr;
	}

	///
	@property T* ptr(T = void)() @trusted const {
		return cast(T*)addr;
	}

	///
	@property Func func(Func)() @trusted if (is(Func == function)) {
		return cast(Func)addr;
	}

	///
	@property Func func(Func)() const @trusted if (is(Func == function)) {
		return cast(Func)addr;
	}

	///
	@property T array(T : X[], X)(size_t length) @trusted {
		return ptr!X[0 .. length];
	}

	///
	@property T array(T : X[], X)(size_t length) @trusted const {
		return ptr!X[0 .. length];
	}

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
	deprecated("You are living dangerously if you use this function!") VirtAddress toVirtual() {
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

	///
	PhysAddress opCast(T : PhysAddress)() {
		return addr.PhysAddress;
	}
}

@safe mixin template MemoryRange(Address) {
	Address start; ///
	Address end; ///

	///
	@property size_t size() const {
		return end.num - start.num;
	}

	///
	bool opCast(T : bool)() {
		return start || end;
	}
}

///
@safe struct VirtMemoryRange {
	mixin MemoryRange!VirtAddress;

	///
	@property T[] array(T = void)() @trusted {
		return start.ptr!T[0 .. (end.num - start.num) / (is(T == void) ? 1 : T.sizeof)];
	}
}

///
@safe struct PhysMemoryRange {
	mixin MemoryRange!PhysAddress;

	/// WARNING: THIS FUNCTION WILL NOT ALWAYS WORK
	deprecated("You are living dangerously if you use this function!") VirtMemoryRange toVirtual() {
		return VirtMemoryRange(start.toVirtual, end.toVirtual);
	}
}

///
@safe struct PhysMemoryRange32 {
	mixin MemoryRange!PhysAddress32;

	///
	@property PhysMemoryRange toX64() {
		return PhysMemoryRange(start.toX64, end.toX64);
	}

	///
	PhysMemoryRange opCast(T : PhysMemoryRange)() {
		return PhysMemoryRange(start.toX64, end.toX64);
	}
}

static assert(VirtAddress.sizeof == size_t.sizeof);
static assert(PhysAddress.sizeof == size_t.sizeof);
static assert(PhysAddress32.sizeof == uint.sizeof);
