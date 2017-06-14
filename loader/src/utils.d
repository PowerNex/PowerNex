module utils;

int memcmp(const(void)* src1, const(void)* src2, size_t size) @trusted @nogc pure nothrow {
	const(ubyte)* p1 = cast(const(ubyte)*)src1;
	const(ubyte)* p2 = cast(const(ubyte)*)src2;
	while (size--) {
		if (*p1 < *p2)
			return -1;
		else if (*p1 > *p2)
			return 1;

		p1++;
		p2++;
	}
	return 0;
}

size_t memcpy(void* dest, const(void)* src, size_t size) @trusted @nogc pure nothrow {
	ubyte* d = cast(ubyte*)dest;
	const(ubyte)* s = cast(const(ubyte)*)src;
	size_t n = size;
	while (n--)
		*(d++) = *(s++);

	return size;
}

size_t strlen(const(char)* str) @trusted @nogc pure nothrow {
	size_t count;
	while (*str)
		count++;
	return count;
}
