module stl.vector;

import stl.address : memmove, memcpy;

alias AllocateFunc = ubyte[]function(size_t wantSize) @safe;
alias FreeFunc = void function(ubyte[] address) @safe;
__gshared AllocateFunc vectorAllocate;
__gshared FreeFunc vectorFree;

template VectorStandardFree(T) {
	void VectorStandardFree(ref T t) @trusted {
		static if (__traits(hasMember, T, "__xdtor")) // Calls __xdtor/__dtor on members and then __dtor the object
			t.__xdtor();
		else static if (__traits(hasMember, T, "__dtor")) // Call just __dtor on object
			t.__dtor();

		const T init = T.init;
		memcpy(&t, &init, T.sizeof);
	}
}

@safe struct Vector(T, size_t staticSize = 0, alias ElementFree = VectorStandardFree!T) if (!is(T == class)) {
public:
	private ubyte[] vectorAllocate(size_t wantSize) @trusted {
		assert(.vectorAllocate);
		return .vectorAllocate(wantSize);
	}

	private void vectorFree(ubyte[] address) @trusted {
		assert(.vectorFree);
		return .vectorFree(address);
	}

	@disable this(this);

	~this() @trusted {
		clear();
		static if (!staticSize)
			vectorFree(cast(ubyte[])_list[0 .. _listLength]);
	}

	ref T put(T value) {
		return put(value);
	}

	ref T put(ref T value) @trusted {
		if (_length == _listLength)
			_expand();
		memcpy(&_list[_length++], &value, T.sizeof);
		return _list[_length - 1];
	}

	bool remove(size_t index) @trusted {
		if (index >= _length)
			return false;

		ElementFree(_list[index]);

		memmove(&_list[index], &_list[index + 1], T.sizeof * (_length - index - 1));
		_length--;

		return true;
	}

	T removeAndGet(size_t index) @trusted {
		assert(index < _length);

		T ret = void;
		memmove(&ret, &_list[index], T.sizeof);

		memmove(&_list[index], &_list[index + 1], T.sizeof * (_length - index - 1));

		_length--;

		return ret;
	}

	bool remove(T obj) @trusted {
		size_t index;
		foreach (ref el; _list[0 .. _length])
			if (el == obj)
				break;
			else
				index++;

		return remove(index);
	}

	void clear() @trusted {
		foreach_reverse (ref obj; _list[0 .. _length])
			ElementFree(obj);

		_length = 0;
	}

	ref T get(size_t index) {
		return opIndex(index);
	}

	ref const(T) get(size_t index) const {
		return opIndex(index);
	}

	ref T opIndex(size_t index) @trusted {
		assert(index < _length);
		return _list[index];
	}

	ref const(T) opIndex(size_t index) @trusted const {
		assert(index < _length);
		return cast(const T)_list[index];
	}

	@property size_t length() const {
		return _length;
	}

	size_t opDollar(size_t pos : 0)() const {
		return _length;
	}

	void opIndexAssign(T val, size_t index) {
		opIndexAssign(val, index);
	}

	void opIndexAssign(ref T val, size_t index) @trusted {
		assert(index < _length);
		memcpy(&_list[index], &val, T.sizeof);
	}

	T[] opIndex() @trusted {
		return _list[0 .. _length];
	}

	T[] opSlice(size_t start, size_t end) {
		return opIndex()[start .. end];
	}

	static if (false && __traits(compiles, () { T a; T b; b = a; }))
		int opApply(scope int delegate(const T) cb) @trusted const {
			int res;
			foreach (i; 0 .. _length) {
				res = cb(_list[i]);
				if (res)
					break;
			}
			return res;
		}

	int opApply(scope int delegate(ref T) cb) @trusted {
		int res;
		foreach (i; 0 .. _length) {
			res = cb(_list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(const ref T) cb) @trusted const {
		int res;
		foreach (i; 0 .. _length) {
			res = cb(_list[i]);
			if (res)
				break;
		}
		return res;
	}

	static if (false && __traits(compiles, () { T a; T b; b = a; }))
		int opApply(scope int delegate(size_t, const T) cb) @trusted const {
			int res;
			foreach (i; 0 .. _length) {
				res = cb(i, _list[i]);
				if (res)
					break;
			}
			return res;
		}

	int opApply(scope int delegate(size_t, ref T) cb) @trusted {
		int res;
		foreach (i; 0 .. _length) {
			res = cb(i, _list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opApply(scope int delegate(size_t, const ref T) cb) @trusted {
		int res;
		foreach (i; 0 .. _length) {
			res = cb(i, _list[i]);
			if (res)
				break;
		}
		return res;
	}

	int opCmp(typeof(this) b) {
		return cast(int)(cast(long)_length - cast(long)b._length);
	}

private:
	// Can't be T[] as this will create an __equals, which in turn needs TypeInfos;
	// Hopefully a future DMD will fix this!
	T* _list;
	size_t _listLength;
	size_t _length;

	static if (staticSize) {
		ubyte[T.sizeof * staticSize] _listData = void;

		void _expand() @trusted {
			import stl.io.log;

			if (!_list) {
				_list = cast(T*)_listData.ptr;
				_listLength = staticSize;
			} else
				Log.fatal("Static sized vector (size: ", staticSize, ") can't be expanded!");
		}

	} else {
		enum _growFactor = 16;

		void _expand() @trusted {
			T[] newList = cast(T[])vectorAllocate(T.sizeof * (_listLength + _growFactor));
			if (_list) {
				memcpy(&newList[0], &_list[0], _listLength * T.sizeof);
				vectorFree(cast(ubyte[])_list[0 .. _listLength]);
			}

			_list = newList.ptr;
			_listLength = newList.length;
		}
	}
}
