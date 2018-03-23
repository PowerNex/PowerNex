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

	auto msg = msg_.fromStringz;
	auto file = file_.fromStringz;

	Log.fatal!(string, string)("assert failed: ", msg, file, "<UNK>", line);
}
