module data.string;

import data.util;
import memory.heap;

size_t strlen(char* str) {
	size_t len = 0;
	while (*(str++))
		len++;
	return len;
}

size_t strlen(char[] str) {
	size_t len = 0;
	char* s = str.ptr;
	while (*(s++) && len < str.length)
		len++;
	return len;
}

size_t itoa(S)(S v, ubyte* buf, ulong len, uint base = 10) if (isNumber!S) {
	assert(1 < base && base <= 16);
	Unqual!S value = v;
	immutable ubyte[] BASE_CHARS = cast(immutable ubyte[])"0123456789ABCDEF";
	size_t pos = len;
	bool sign = false;

	if (value < 0) {
		sign = true;
		value = -value;
	}

	do {
		buf[--pos] = BASE_CHARS[value % base];
		value /= base;
	}
	while (value);

	if (sign)
		buf[--pos] = '-';

	return pos;
}

string fromStringz(char* str) {
	size_t len = str.strlen;
	char[] a = str[0 .. str.strlen];

	char* s = cast(char*)GetKernelHeap.Alloc(len);
	memcpy(s, str, len);

	return cast(string)s[0 .. len];
}

string fromStringz(char[] str) {
	size_t len = str.strlen;
	char[] a = str[0 .. str.strlen];

	char* s = cast(char*)GetKernelHeap.Alloc(len);
	memcpy(s, str.ptr, len);

	return cast(string)s[0 .. len];
}
