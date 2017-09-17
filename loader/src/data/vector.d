module data.vector;

import memory.heap : Heap;

@safe struct Vector(T) if (!is(T == class)) {
public:
	 ~this() {
		clear();
		Heap.free(_list);
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

		static if (is(T == struct))
			typeid(T).destroy(&_list[index]);

		_list[index .. $ - 1] = _list[index + 1 .. $];
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
		static if (is(T == struct))
			foreach (ref obj; _list[0 .. _length])
				typeid(T).destroy(&obj);
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

private:
	enum _growFactor = 16;

	T[] _list;
	size_t _length;

	void _expand() @trusted {
		T[] newList = cast(T[])Heap.allocate(T.sizeof * (_list.length + _growFactor));
		newList[0 .. _list.length] = _list[];
		Heap.free(_list);
		_list = newList;
	}
}
