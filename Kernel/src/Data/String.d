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

long indexOf(char[] str, char ch, long start = 0) {
	long idx = start;
	while (idx < str.length)
		if (str[idx] == ch)
			return idx;
		else
			idx++;
	return -1;
}

long indexOfLast(char[] str, char ch, long start = 0) {
	long idx = start ? start : str.length - 1;
	while (idx > -1)
		if (str[idx] == ch)
			return idx;
		else
			idx--;
	return -1;
}

char[] strip(char[] str) {
	if (!str.length)
		return str;
	size_t start;
	size_t end = str.length;
	while (str[start] == ' ')
		start++;
	while (end > 0 && str[end - 1] == ' ')
		end--;

	return str[start .. end];
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

long atoi(string str, uint base = 10) {
	long result;
	immutable char[] BASE_CHARS = cast(immutable char[])"0123456789ABCDEF";

	foreach (ch; str) {
		long value;
		for (value = 0; value <= base; value++)
			if (BASE_CHARS[value] == ch)
				break;
		if (value > base)
			return result;

		result = result * base + value;
	}
	return result;
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
