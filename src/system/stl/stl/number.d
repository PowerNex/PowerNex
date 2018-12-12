/**
 * A couple of math functions.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.number;

///
T abs(T)(T i) {
	if (i < 0)
		return -i;
	return i;
}

// https://github.com/Vild/PowerNex/commit/9db5276c34a11d86213fe7b19878762a9461f615#commitcomment-22324396
///
ulong log2(ulong value) {
	ulong result;
	asm pure @trusted nothrow @nogc {
		bsr RAX, value;
		mov result, RAX;
	}

	//2 ^ result == value means value is a power of 2 and we dont need to round up
	if (1 << result != value)
		result++;

	return result;
}

///
T min(T)(T a, T b) {
	return a < b ? a : b;
}

///
T max(T)(T a, T b) {
	return a > b ? a : b;
}
