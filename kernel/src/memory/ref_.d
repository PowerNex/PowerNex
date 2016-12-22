module memory.ref_;

import memory.allocator;

struct Ref(T) {
public:
	enum isClass = is(T == class) || is(T == interface);
	static if (isClass)
		alias E = T;
	else
		alias E = T*;

	this(E obj, IAllocator allocator = kernelAllocator) {
		this(obj, obj ? allocator.make!size_t(0) : null, allocator);
	}

	this(E obj, size_t* counter, IAllocator allocator = kernelAllocator) {
		_allocator = allocator;
		_obj = obj;
		_counter = counter;
		(*_counter)++;
	}

	this(this) {
		if (_counter)
			(*_counter)++;
	}

	this(typeof(this) other) {
		_allocator = other._allocator;
		_obj = other._obj;
		_counter = other._counter;
		(*_counter)++;
	}

	~this() {
		if (_allocator && _obj && _counter && --(*_counter) == 0) {
			_allocator.dispose(_obj);
			_allocator.dispose(_counter);
		}
		_allocator = null;
		_obj = null;
		_counter = null;
	}

	ref typeof(this) opAssign(typeof(this) other) {
		__dtor();
		_allocator = other._allocator;
		_obj = other._obj;
		_counter = other._counter;

		if (_counter)
			(*_counter)++;
		return this;
	}

	bool opCast(X)() const if (is(X == bool)) {
		return !!_obj;
	}

	X opCast(X : Ref!T, T)() if (isClass && is(E : T)) {
		return X(cast(T)_obj, _counter, _allocator);
	}

	E opApply() {
		return _obj;
	}

	@property E data() {
		return _obj;
	}

	alias _obj this;
private:
	IAllocator _allocator;
	public E _obj;
	size_t* _counter;
}
