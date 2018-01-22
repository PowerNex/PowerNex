/**
 * Helper functions for manageing different strings.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.text;

///
@safe struct BinaryInt {
	ulong number; ///
}

///
@safe struct HexInt {
	ulong number; ///
}

///
nothrow pure size_t strlen(const(char)* str) @trusted {
	if (!str)
		return 0;
	size_t len = 0;
	while (*(str++))
		len++;
	return len;
}

///
size_t strlen(const(char)[] str) @trusted {
	size_t len = 0;
	const(char)* s = str.ptr;
	while (*(s++) && len < str.length)
		len++;
	return len;
}

///
long indexOf(T)(inout(T)[] haystack, T needle, long start = 0) @trusted {
	long idx = start;
	while (idx < haystack.length)
		if (haystack[idx] == needle)
			return idx;
		else
			idx++;
	return -1;
}

///
long indexOfLast(T)(inout(T)[] haystack, T needle, long start = 0) @trusted {
	long idx = start ? start : haystack.length - 1;
	while (idx > -1)
		if (haystack[idx] == needle)
			return idx;
		else
			idx--;
	return -1;
}

///
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

///
string itoa(S)(S v, char[] buf, uint base = 10, size_t padLength = 1, char padChar = '0') @trusted
		if (from!"stl.trait".isNumber!S) {
	auto start = itoa(v, buf.ptr, buf.length, base, padLength, padChar);
	return cast(string)buf[start .. $];
}

///
size_t itoa(S)(S v, char* buf, ulong len, uint base = 10, size_t padLength = 1, char padChar = '0') @trusted
		if (from!"stl.trait".isNumber!S) {
	import stl.trait : Unqual;

	assert(1 < base && base <= 16);
	Unqual!S value = v;
	immutable char[] baseChars = cast(immutable char[])"0123456789ABCDEF";
	size_t pos = len;
	bool sign = false;

	if (padLength > len)
		padLength = len;

	if (value < 0) {
		sign = true;
		value = -value;
		if (padLength)
			padLength--;
	}

	do {
		buf[--pos] = baseChars[value % base];
		value /= base;
	}
	while (value);

	while (len - pos < padLength)
		buf[--pos] = padChar;

	if (sign)
		buf[--pos] = '-';

	return pos;
}

///
long atoi(string str, uint base = 10) @trusted {
	long result;
	immutable char[] baseChars = cast(immutable char[])"0123456789ABCDEF";

	foreach (ch; str) {
		long value;
		for (value = 0; value <= base; value++)
			if (baseChars[value] == ch)
				break;
		if (value > base)
			return result;

		result = result * base + value;
	}
	return result;
}

///
string dtoa(double v, char[] buf, uint base = 10) @trusted {
	auto start = dtoa(v, buf.ptr, buf.length, base);
	return cast(string)buf[start .. $];
}

///
bool isNan(double value) @trusted {
	enum ulong nanMask = 0x7FFUL;
	union storage {
		double v;
		ulong i;
	}

	storage s;
	s.v = value;

	return ((s.i >> 51UL) & nanMask) == nanMask;
}

///
size_t dtoa(double value, char* buf, ulong len, uint base = 10) @trusted {
	assert(1 < base && base <= 16);

	size_t pos = len;
	if (value.isNan) {
		buf[--pos] = 'N';
		buf[--pos] = 'a';
		buf[--pos] = 'N';
		return pos;
	} else if (value == double.infinity) {
		buf[--pos] = 'f';
		buf[--pos] = 'n';
		buf[--pos] = 'I';
		return pos;
	} else if (value == -double.infinity) {
		buf[--pos] = 'f';
		buf[--pos] = 'n';
		buf[--pos] = 'I';
		buf[--pos] = '-';
		return pos;
	}

	bool sign = false;
	if (value < 0) {
		sign = true;
		value = -value;
	}

	ulong exponent = cast(ulong)value;
	double fraction = value - exponent;
	immutable char[] baseChars = cast(immutable char[])"0123456789ABCDEF";

	// Fraction
	char[16] fracTmp;
	int fracPos;
	fraction *= base;
	do {
		fracTmp[fracPos++] = baseChars[cast(ulong)fraction % base];
		fraction *= base;
	}
	while (fraction && fracPos < fracTmp.length);

	// Reverse Fraction to buf
	while (--fracPos >= 0)
		buf[--pos] = fracTmp[fracPos];

	buf[--pos] = '.';
	// Exponent
	do {
		buf[--pos] = baseChars[exponent % base];
		exponent /= base;
	}
	while (exponent);

	if (sign)
		buf[--pos] = '-';

	return pos;
}

///
string fromStringz(const(char)* str) @trusted {
	return cast(string)str[0 .. str.strlen];
}

///
string fromStringz(const(char)[] str) @trusted {
	return cast(string)str.ptr[0 .. str.strlen];
}
