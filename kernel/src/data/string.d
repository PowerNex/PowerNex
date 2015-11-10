module data.string;

import data.util;

size_t itoa(S)(S v, ubyte* buf, size_t len, uint base = 10) if(isNumber!S) {
	assert(1 < base && base <= 16);
	Unqual!S value = v;
	immutable ubyte BASE_CHARS[] = cast(immutable ubyte[])"0123456789ABCDEF";
	size_t pos = len;
	bool sign = false;
	if(value < 0) {
		sign = true;
		value = -value;
	}
	do {
		buf[--pos] = BASE_CHARS[value % base];
		value /= base;
	} while(value);
	if(sign)
		buf[--pos] = '-';
	return pos;
}
