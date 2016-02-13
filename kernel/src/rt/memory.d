/**
	Memory management tips

	1) use StackArrays whenever you can
	2) HeapArrays are the second choice, they are refcounted automatically
	3) OwnedArrays are like heap arrays, but non-copyable
*/

// non-refcounted, non-copyable
struct OwnedArray(T) {
	@disable this();
	@disable this(this);
	this(size_t capacity) {

	}

	~this() {

	}
}

// FIXME: finis this and decide if it is even a good idea
struct RefCountedSlice(T) {
	@disable this();
	HeapArrayBacking backing;
	this(HeapArray!T ha, size_t start, size_t end) {
		this.backing = ha.backing;
		this.start = start;
		this.end = end;
		backing.refcount++;
	}

	this(this) {
		backing.refcount++;
	}

	~this() {
		backing.refcount--;
		if (backing.refcount == 0)
			manual_free(backing);
	}

	typeof(this) copy() {
		HeapArray!T cp = HeapArray!T(this.backing.capacity);
		cp ~= this.slice();
		return cp;
	}

	size_t start;
	size_t end;
	T opIndex(size_t idx, string file = __FILE__, size_t line = __LINE__) {
		return backing.at(idx + start, file, line);
	}

	T[] slice() {
		return backing.slice[start .. end];
	}

	alias slice this;

}

// introduces double indirection but it is easy
mixin template SimpleRefCounting(T, string freeCode) {
	final class RefCount {
		T payload;
		int refcount;
		this(T t) {
			payload = t;
		}

		~this() {
			assert(refcount == 0);
			mixin(freeCode);
		}
	}

	private RefCount payload;
	@property T getPayload() {
		return payload.payload;
	}

	alias getPayload this;
	@disable this();
	this(T t) {
		payload = new RefCount(t);
	}

	this(typeof(this) reference) {
		payload = reference.payload;
		payload.refcount++;
	}

	this(this) {
		payload.refcount++;
	}

	~this() {
		payload.refcount--;
		if (payload.refcount == 0)
			manual_free(payload);
	}
}

struct HeapClosure(T) if (is(T == delegate)) {
	mixin SimpleRefCounting!(T, q{
		char[16] buffer;
		write("\nfreeing closure ", intToString(cast(size_t) payload.ptr, buffer),"\n");
		manual_free(payload.ptr);
	});
}

HeapClosure!T makeHeapClosure(T)(T t) { // if(__traits(isNested, T)) {
	return HeapClosure!T(t);
}

struct StackArray(T, int maxLength) {
	T[maxLength] buffer;
	T[] slice() {
		return buffer[0 .. this.length];
	}

	alias slice this;

	int length;

	typeof(this) opOpAssign(string op : "~")(in T[] rhs) {
		buffer[this.length .. this.length + rhs.length] = rhs[];
		this.length += rhs.length;
		return this;
	}
}

final class HeapArrayBacking(T) {
	T* backing;
	size_t capacity;
	size_t length;
	int refcount;

	T[] slice() {
		return backing[0 .. length];
	}

	void setCapacity(size_t capacity) {
		backing = cast(T*)manual_realloc(backing, capacity * T.sizeof);
		this.capacity = capacity;
		if (length > capacity)
			length = capacity;
	}

	void append(T rhs) {
		if (length == capacity) {
			throw new Exception("out of space");
			// FIXME: realloc?
		}
		backing[this.length] = rhs;
		this.length++;
	}

	void append(in T[] rhs) {
		if (length == capacity) {
			throw new Exception("out of space");
			// FIXME: realloc?
		}
		backing[this.length .. this.length + rhs.length] = rhs[];
		this.length += rhs.length;
	}

	T at(size_t idx, string file = __FILE__, size_t line = __LINE__) {
		if (idx >= length)
			throw new Exception("range error", file, line);
		return backing[idx];
	}

	this() {

	}

	~this() {
		assert(this.refcount == 0);
		if (backing !is null) {
			manual_free(backing);
		}
	}
}

struct HeapArray(T) {
	HeapArrayBacking!T backing;
	@disable this();

	this(size_t capacity) {
		backing = new HeapArrayBacking!T;
		backing.setCapacity(capacity);
		backing.refcount++;
	}

	this(HeapArray!T reference) {
		backing = reference.backing;
		backing.refcount++;
	}

	this(this) {
		backing.refcount++;
	}

	~this() {
		backing.refcount--;
		if (backing.refcount == 0)
			manual_free(backing);
	}

	typeof(this) copy() {
		HeapArray!T cp = HeapArray!T(this.backing.capacity);
		cp ~= this.slice();
		return cp;
	}

	typeof(this) opOpAssign(string op : "~")(in T[] rhs) {
		backing.append(rhs);
		return this;
	}

	typeof(this) opOpAssign(string op : "~")(in T rhs) {
		backing.append(rhs);
		return this;
	}

	T opIndex(size_t idx, string file = __FILE__, size_t line = __LINE__) {
		return backing.at(idx, file, line);
	}

	T[] slice() {
		return backing.slice;
	}

	alias slice this;
}
