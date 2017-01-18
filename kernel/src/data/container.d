module data.container;

import data.range;
import memory.allocator;

struct Nullable(T) {
	this(T value) {
		_value = value;
		_isNull = false;
	}

	~this() {
		static if (is(typeof(_value.__dtor())))
			if (_isNull)
				_value.__dtor();
	}

	T get() {
		assert(!_isNull);
		return _value;
	}

	@property bool isNull() {
		return _isNull;
	}

private:
	T _value;
	bool _isNull = true;
}

interface IContainer(E) : OutputRange!E {
	bool remove(size_t index);
	E get(size_t index);
	ref E opIndex(size_t index);
	const(E) opIndex(size_t index) const;

	@property size_t length() const;
	alias opDollar = length;

	void opIndexAssign(E val, size_t index);
	//	RandomFiniteAssignable!E opIndex();
	E[] opIndex();
	E[] opSlice(size_t start, size_t end);

	int opApply(scope int delegate(const E) cb) const;
	int opApply(scope int delegate(ref E) cb);
	int opApply(scope int delegate(size_t, const E) cb) const;
	int opApply(scope int delegate(size_t, ref E) cb);
}

class Vector(E) : IContainer!E {
public:
	this(IAllocator allocator) {
		_allocator = allocator;
	}

	ref E put(E value) {
		if (_length == _capacity)
			_expand();
		_list[_length++] = value;
		return _list[_length - 1];
	}

	bool remove(size_t index) {
		if (index >= _length)
			return false;

		static if (is(typeof(_list[0].__dtor())))
			_list[index].__dtor();

		for (; index < _length - 1; index++)
			_list[index] = _list[index + 1];
		_list[index] = E.init;
		_length--;
		return true;
	}

	E get(size_t index) {
		assert(index < _length);
		return _list[index];
	}

	ref E opIndex(size_t index) {
		assert(index < _length);
		return _list[index];
	}

	const(E) opIndex(size_t index) const {
		assert(index < _length);
		return cast(const E)_list[index];
	}

	@property size_t length() const {
		return _length;
	}

	void opIndexAssign(E val, size_t index) {
		assert(index < _length);
		_list[index] = val;
	}

	E[] opIndex() {
		return _list[0 .. _length];
	}

	E[] opSlice(size_t start, size_t end) {
		return opIndex()[start .. end];
	}

	int opApply(scope int delegate(const E) cb) const {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(ref E) cb) {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(size_t, const E) cb) const {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(i, _list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(size_t, ref E) cb) {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(i, _list[i]);
			if (res)
				break;
		}
		return res;
	}

private:
	enum _growFactor = 16;
	IAllocator _allocator;

	E[] _list;
	size_t _length;
	size_t _capacity;

	void _expand() {
		_allocator.expandArray(_list, _growFactor);
		_capacity += _growFactor;
	}
}

struct Key(K, V) {
	K key;
	V value;

	~this() {
		static if (is(typeof(key.__dtor())))
			key.__dtor();
		static if (is(typeof(value.__dtor())))
			value.__dtor();
	}
}

class Map(K, V) { //TODO: Somehow fit this into IContainer
public:
	alias Key = .Key!(K, V);

	this(IAllocator allocator) {
		_allocator = allocator;
	}

	bool remove(K key) {
		size_t index;
		for (; index < _length; index++)
			if (_list[index].key == key)
				break;

		if (index >= _length)
			return false;

		_list[index].__dtor();

		for (; index < _length - 1; index++)
			_list[index] = _list[index + 1];
		_list[index] = Key.init;
		_length--;
		return true;
	}

	Nullable!V get(K key) {
		for (size_t i; i < _length; i++)
			if (_list[i].key == key)
				return Nullable!V(_list[i].value);

		return Nullable!V();
	}

	ref V opIndex(K key) {
		for (size_t i; i < _length; i++)
			if (_list[i].key == key)
				return _list[i].value;
		assert(0);
	}

	const(V) opIndex(K key) const {
		for (size_t i; i < _length; i++)
			if (_list[i].key == key)
				return cast(const V)_list[i].value;
		assert(0);
	}

	@property size_t length() const {
		return _length;
	}

	ref V opIndexAssign(V value, K key) {
		for (size_t i; i < _length; i++)
			if (_list[i].key == key)
				_list[i].value = value;

		if (_length == _capacity)
			_expand();
		_list[_length++].value = value;
		return _list[_length - 1].value;
	}

	Key[] opIndex() {
		return _list[0 .. _length];
	}

	Key[] opSlice(size_t start, size_t end) {
		return opIndex()[start .. end];
	}

	int opApply(scope int delegate(const V) cb) const {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i].value);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(ref V) cb) {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i].value);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(K, const V) cb) const {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i].key, _list[i].value);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(K, ref V) cb) {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i].key, _list[i].value);
			if (res)
				break;
		}
		return res;
	}

private:
	enum _growFactor = 16;
	IAllocator _allocator;

	Key[] _list;
	size_t _length;
	size_t _capacity;

	void _expand() {
		_allocator.expandArray(_list, _growFactor);
		_capacity += _growFactor;
	}
}
