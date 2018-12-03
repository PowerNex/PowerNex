// PowerNexOS runtime
// Based on object.d in druntime
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file BOOST-LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

module object;

import stl.trait : isVersion;

static assert(isVersion!"PowerNex", "\x1B[31;1m\n\n
+--------------------------------------- ERROR ---------------------------------------+
|                                                                                     |
|  You need to follow the build steps that are specified inside the README.org file!  |
|                                                                                     |
+-------------------------------------------------------------------------------------+
\n\n\x1B[0m");

version (X86_64) {
	alias size_t = ulong;
	alias ptrdiff_t = long;
	alias string = immutable(char)[]; // TODO: Create wrapper for strings
}

bool __equals(T1, T2)(T1[] lhs, T2[] rhs) {
	import stl.trait : Unqual;

	alias RealT1 = Unqual!T1;
	alias RealT2 = Unqual!T2;

	static if (is(RealT1 == RealT2) && is(RealT1 == void)) {
		auto lhs_ = cast(ubyte[])lhs;
		auto rhs_ = cast(ubyte[])rhs;
		if (lhs_.length != rhs_.length)
			return false;
		foreach (idx, a; lhs_)
			if (a != rhs_[idx])
				return false;
		return true;
	} else static if (is(RealT1 == RealT2)) {
		if (lhs.length != rhs.length)
			return false;
		foreach (idx, a; lhs)
			if (a != rhs[idx])
				return false;
		return true;
	} else static if (__traits(compiles, { RealT2 a; auto b = cast(RealT1)a; }())) {
		if (lhs.length != rhs.length)
			return false;
		foreach (idx, a; lhs)
			if (a != cast(RealT1)rhs[idx])
				return false;
		return true;

	} else {
		pragma(msg, "I don't know what to do!: ", __PRETTY_FUNCTION__);
		assert(0, "I don't know what to do!");
	}
}

void __switch_error()(string file = __FILE__, size_t line = __LINE__) {
	assert(0, "Final switch fallthough! " ~ __PRETTY_FUNCTION__);
}

extern (C) void[] _d_arraycast(ulong toTSize, ulong fromTSize, void[] a) @trusted {
	import stl.io.log : Log;

	auto len = a.length * fromTSize;
	if (len % toTSize != 0)
		Log.fatal("_d_arraycast failed: ", len, " % ", toTSize, " != 0");

	return a[0 .. len / toTSize];
}

extern (C) void[] _d_arraycopy(size_t size, void[] from, void[] to) @trusted {
	import stl.address : memmove;

	memmove(to.ptr, from.ptr, from.length * size);
	return to;
}

extern (C) void __assert(const char* msg_, const char* file_, int line) @trusted {
	import stl.text : fromStringz;
	import stl.io.log : Log;
	import stl.io.e9;

	auto msg = msg_.fromStringz;
	auto file = file_.fromStringz;

	E9.write("assert failed: ", msg, file, '0' + ((line / 1000) % 10), '0' + ((line / 100) % 10), '0' + ((line / 10) % 10),
			'0' + ((line / 1) % 10));

	Log.fatal!(string, string)("assert failed: ", msg, file, "<UNK>", line);
}

// From https://github.com/dlang/druntime/commit/96408ecb775f06809314fa3eded3158d60b40e31

// compiler frontend lowers dynamic array comparison to this
extern (C) bool __ArrayEq(T1, T2)(T1[] a, T2[] b) {
	if (a.length != b.length)
		return false;
	foreach (size_t i; 0 .. a.length)
		if (a[i] != b[i])
			return false;

	return true;
}

// compiler frontend lowers struct array postblitting to this
extern (C) void __ArrayPostblit(T)(T[] a) {
	foreach (ref T e; a)
		e.__xpostblit();
}

// compiler frontend lowers dynamic array deconstruction to this
extern (C) void __ArrayDtor(T)(T[] a) {
	foreach_reverse (ref T e; a)
		e.__xdtor();
}

// Based on https://github.com/dlang/druntime/commit/2aed1042c633516e236f21b9dd39fd3f472b65bf#diff-a68e58fcf0de5aa198fcaceafe4e8cf9

/**
Used by `__ArrayCast` to emit a descriptive error message.
It is a template so it can be used by `__ArrayCast` in -betterC
builds.  It is separate from `__ArrayCast` to minimize code
bloat.
Params:
    fromType = name of the type being cast from
    fromSize = total size in bytes of the array being cast from
    toType   = name of the type being cast o
    toSize   = total size in bytes of the array being cast to
 */
private void onArrayCastError()(string fromType, size_t fromSize, string toType, size_t toSize) @trusted {
	import stl.io.log : Log;
	import stl.io.e9;

	E9.write("onArrayCastError failed: fromType: ", fromType, ", fromSize: ", fromSize, " toType: ", toType, ", toSize: ", toSize);
	Log.fatal("onArrayCastError failed: fromType: ", fromType, ", fromSize: ", fromSize, " toType: ", toType, ", toSize: ", toSize);
}

/**
The compiler lowers expressions of `cast(TTo[])TFrom[]` to
this implementation.
Params:
    from = the array to reinterpret-cast
Returns:
    `from` reinterpreted as `TTo[]`
 */
extern (C) TTo[] __ArrayCast(TFrom, TTo)(TFrom[] from) @nogc pure @trusted {
	const fromSize = from.length * TFrom.sizeof;
	const toLength = fromSize / TTo.sizeof;

	if ((fromSize % TTo.sizeof) != 0)
		onArrayCastError(TFrom.stringof, fromSize, TTo.stringof, toLength * TTo.sizeof);

	struct Array {
		size_t length;
		void* ptr;
	}

	auto a = cast(Array*)&from;
	a.length = toLength; // jam new length
	return *cast(TTo[]*)a;
}
