module Data.String;

import Data.Util;
import Memory.Heap;

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

string itoa(S)(S v, char[] buf, uint base = 10) if (isNumber!S) {
	auto start = itoa(v, buf.ptr, buf.length, base);
	return cast(string)buf[start .. $];
}

size_t itoa(S)(S v, char* buf, ulong len, uint base = 10) if (isNumber!S) {
	assert(1 < base && base <= 16);
	Unqual!S value = v;
	immutable char[] BASE_CHARS = cast(immutable char[])"0123456789ABCDEF";
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
