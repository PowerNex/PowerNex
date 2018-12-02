/**
 * Helper functions for memory management.
 *
 * Copyright: © 2015-2018, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module rt.memory;

pure void* memset(return void* s, ubyte c, size_t n) @trusted nothrow {
	ubyte* p = cast(ubyte*)s;
	foreach (ref b; p[0 .. n])
		b = c;
	return s;
}

pure void* memcpy(return void* s1, scope const void* s2, size_t n) @trusted nothrow {
	if (s1 == s2)
		return s1;

	ubyte* p1 = cast(ubyte*)s1;
	const(ubyte)* p2 = cast(const(ubyte)*)s2;

	if (p1 < p2) {
		while (n > 7) {
			*cast(ulong*)p1 = *cast(const(ulong)*)p2;
			p1 += 8;
			p2 += 8;
			n -= 8;
		}

		while (n--)
			*p1++ = *p2++;
	} else {
		p1 += n;
		p2 += n;
		while (n > 7) {
			p1 -= 8;
			p2 -= 8;
			n -= 8;
			*cast(ulong*)p1 = *cast(const(ulong)*)p2;
		}

		while (n--)
			*--p1 = *--p2;
	}
	return s1;
}

pure void* memmove(return void* s1, scope const void* s2, size_t n) @trusted nothrow {
	return memcpy(s1, s2, n);
}

pure int memcmp(scope const void* s1, scope const void* s2, size_t n) @trusted nothrow {
	auto p1 = cast(const(ubyte)*)s1;
	auto p2 = cast(const(ubyte)*)s2;
	for (; n; n--, p1++, p2++)
		if (*p1 != *p2)
			return *p1 - *p2;
	return 0;
}
