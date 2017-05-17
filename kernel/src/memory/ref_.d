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
		if (_counter)
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
		if (_counter)
			(*_counter)++;
	}

	~this() {
		_free();
	}

	ref typeof(this) opAssign(typeof(null)) {
		_free();
		return this;
	}

	ref typeof(this) opAssign(typeof(this) other) {
		_free();
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

	X opCast(X : Ref!T, T)() if (isClass && (is(E : T) || is(T : E))) {
		return X(cast(T)_obj, _counter, _allocator);
	}

	E opUnary(string op)() if (op == "*") {
		return _obj;
	}

	const(E) opUnary(string op)() const if (op == "*") {
		return _obj;
	}

	@property E data() {
		return _obj;
	}

	@property const(E) data() const {
		return _obj;
	}

	@property size_t counter() const {
		if (_counter)
			return *_counter;
		else
			return 0;
	}

private:
	public E _obj; // Must be first
	IAllocator _allocator;
	size_t* _counter;

	void _free() {
		import io.log;

		if (_obj && _counter) {
			log.info("Trying to free: ", cast(void*)_obj);
			log.info("\tT: ", T.stringof);
			log.info("\tcounter: ", _counter ? (*_counter) - 1 : ulong.max);
		}
		if (_allocator && _obj && _counter && --(*_counter) == 0) {
			_allocator.dispose(_obj);
			_allocator.dispose(_counter);

			//log.info("Freed: ", cast(void*)_obj, " T: ", T.stringof);
		}
		_allocator = null;
		_obj = null;
		_counter = null;
	}
}
