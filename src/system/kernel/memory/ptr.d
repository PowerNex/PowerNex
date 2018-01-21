module memory.ptr;

import memory.allocator;

import data.util : isClass;

struct PtrCounter {
public:
	this(this) {
		if (_counter)
			(*_counter)++;
	}

	this(IAllocator allocator, size_t initValue = 1) {
		_allocator = allocator;
		_counter = allocator.make!size_t(initValue);
	}

	this(ref PtrCounter other) {
		_allocator = other._allocator;
		_counter = other._counter;
		if (_counter)
			(*_counter)++;
	}

	~this() {
		reset();
	}

	size_t get() {
		return (_counter) ? *_counter : 0;
	}

	size_t get() const {
		return (_counter) ? *_counter : 0;
	}

	void reset() {
		if (!_counter)
			return;

		_counter--;
		if (!_counter)
			_allocator.dispose(_counter);

		_allocator = null;
		_counter = null;
	}

	void opAssign(ref PtrCounter other) {
		_allocator = other._allocator;
		_counter = other._counter;
		if (_counter)
			(*_counter)++;
	}

private:
	IAllocator _allocator;
	size_t* _counter;
}

struct SharedPtr(T) {
public:
	static if (_isClass)
		alias DataType = T;
	else
		alias DataType = T*;

	this(Args...)(IAllocator allocator, auto ref Args args) {
		_allocator = allocator;
		_data = allocator.make!T(args);
		_counter = PtrCounter(allocator);
	}

	this(ref SharedPtr!T other) {
		_allocator = other._allocator;
		_data = other._data;
		_counter = other._counter;
	}

	this(X : SharedPtr!XT, XT)(ref X other) if (_isClass && (is(T : XT) || is(XT : T))) {
		_allocator = other._allocator;
		_data = cast(DataType)other._data;
		_counter = other._counter;
	}

	this(this) {
		// Automagically handled by PtrCounter.this(this)!
	}

	~this() {
		reset();
	}

	auto opDispatch(string s)() {
		return mixin("_data." ~ s);
	}

	auto opDispatch(string s, Args...)(Args args) {
		return mixin("_data." ~ s)(args);
	}

	DataType get() {
		return _data;
	}

	ref const(DataType) get() const {
		return _data;
	}

	DataType opUnary(string op : "*")() {
		return get();
	}

	ref const(DataType) opUnary(string op : "*")() const {
		return get();
	}

	bool opCast(T : bool)() {
		return !!_data;
	}

	auto opCast(X : SharedPtr!XT, XT)() if (_isClass && (is(T : XT) || is(XT : T))) {
		return X(this);
	}

	void opAssign(SharedPtr!T other) {
		reset();
		_allocator = other._allocator;
		_data = other._data;
		_counter = other._counter;
	}

	void reset() {
		if (!_data)
			return;

		if (_counter.get == 1)
			_allocator.dispose(_data);

		_allocator = null;
		_data = null;
		_counter.reset();
	}

private:
	enum _isClass = isClass!T;

	IAllocator _allocator;
	DataType _data;
	PtrCounter _counter;
}
