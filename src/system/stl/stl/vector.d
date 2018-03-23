module stl.vector;

import stl.address : memmove, memcpy;

alias AllocateFunc = void[]function(size_t wantSize) @safe;
alias FreeFunc = void function(void[] address) @safe;
__gshared AllocateFunc vectorAllocate;
__gshared FreeFunc vectorFree;

@safe struct Vector(T) if (!is(T == class)) {
public:
	void[] vectorAllocate(size_t wantSize) @trusted {
		assert(.vectorAllocate);
		return .vectorAllocate(wantSize);
	}

	void vectorFree(void[] address) @trusted {
		assert(.vectorFree);
		return .vectorFree(address);
	}

	~this() {
		clear();
		vectorFree(_list);
	}

	ref T put(T value) {
		if (_length == _list.length)
			_expand();
		_list[_length++] = value;
		return _list[_length - 1];
	}

	ref T put(ref T value) {
		if (_length == _list.length)
			_expand();
		_list[_length++] = value;
		return _list[_length - 1];
	}

	bool remove(size_t index) @trusted {
		if (index >= _length)
			return false;

		static if (is(typeof({ T a; a.__dtor(); })))
			_list[index].__dtor;

		memmove(&_list[index], &_list[index + 1], T.sizeof * (_length - index - 1));
		_length--;

		return true;
	}

	bool remove(T obj) {
		size_t index;
		while (index < _length)
			if (_list[index] == obj)
				break;
			else
				index++;

		return remove(index);
	}

	void clear() @trusted {
		static if (is(typeof({ T a; a.__dtor(); })))
			foreach (ref obj; _list[0 .. _length])
				obj.__dtor();
		_length = 0;
	}

	ref T get(size_t index) {
		assert(index < _length);
		return _list[index];
	}

	ref const(T) get(size_t index) const {
		assert(index < _length);
		return _list[index];
	}

	ref T opIndex(size_t index) {
		assert(index < _length);
		return _list[index];
	}

	ref const(T) opIndex(size_t index) const {
		assert(index < _length);
		return cast(const T)_list[index];
	}

	@property size_t length() const {
		return _length;
	}

	void opIndexAssign(T val, size_t index) {
		assert(index < _length);
		_list[index] = val;
	}

	T[] opIndex() {
		return _list[0 .. _length];
	}

	T[] opSlice(size_t start, size_t end) {
		return opIndex()[start .. end];
	}

	int opApply(scope int delegate(const T) cb) @trusted const {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(ref T) cb) @trusted {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(const ref T) cb) @trusted {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(_list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(size_t, const T) cb) @trusted const {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(i, _list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(size_t, ref T) cb) @trusted {
		int res;
		for (size_t i = 0; i < _length; i++) {
			res = cb(i, _list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(size_t, const ref T) cb) @trusted {
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

	T[] _list;
	size_t _length;

	void _expand() @trusted {
		T[] newList = cast(T[])vectorAllocate(T.sizeof * (_list.length + _growFactor));
		memcpy(&newList[0], &_list[0], _list.length * T.sizeof);
		vectorFree(_list);
		_list = newList;
	}
}
