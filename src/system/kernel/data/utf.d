module data.utf;

import io.log;

dchar parseUTF8(ubyte[] data, ref size_t bytesUsed) {
	__gshared immutable ubyte[] maskNeeded = [0b0111_1111, 0b0011_1111, 0b0001_1111, 0b0000_1111, 0b0000_0111];
	uint ch;
	if (!data.length) {
		bytesUsed = 0;
		return dchar.init;
	}

	size_t expectedCharSize = 0;
	for (size_t i = 0; i < 5; i++)
		if ((data[0] >> (7 - i)) & 0x1)
			expectedCharSize++;
		else
			break;

	if (expectedCharSize > 3) { // Invalid, char cannot have more than 4 bytes
		Log.debug_("Invalid, cannot have more than 4 bytes");
		Log.warning("\t Error byte: ", cast(void*)data[0]);
		goto error;
	} else if (expectedCharSize == 0) { // Doesn't require another bytes
		bytesUsed = 1;
		return cast(dchar)data[0];
	} else if (expectedCharSize == 1) {
		// If expectedCharSize is 1, it is a 'extra' char
		// expectedCharSize can only be 0 (Means 1), 2, 3
		Log.debug_("Invalid byte");
		Log.warning("\t Error byte: ", cast(void*)data[0]);
		goto error;
	}

	if (data.length < expectedCharSize) {
		Log.debug_("Data array is too small! needed size: ", expectedCharSize, " is: ", data.length);
		goto error;
	}

	ch = data[0] & maskNeeded[expectedCharSize];

	for (size_t i = 1; i < expectedCharSize; i++) {
		if ((data[i] & 0b1100_0000) != 0b1000_0000) {
			Log.debug_("Expected a 'extra' char, found a data char instead");
			Log.warning("\t Error byte: ", cast(void*)data[i], " idx: ", i);
			goto error;
		}

		ch <<= 6;
		ch |= data[i] & 0b0011_1111;
	}

	bytesUsed = expectedCharSize;
	return cast(dchar)ch;

error:
	bytesUsed = 1;
	return dchar.init;
}

ubyte[4] toUTF8(dchar ch, ref size_t bytesUsed) {
	ubyte[4] ret;
	uint ich = cast(uint)ch;
	if (ich <= 0x7F) {
		ret[0] = cast(ubyte)ch;
		bytesUsed = 1;
	} else if (ich <= 0x7FF) {
		ret[0] = cast(ubyte)ch & /* Clear third top bit */ ~20 | /* Set two upper bits */ 0xC0;
		ret[1] = cast(ubyte)(ch >> 5) | /* Clear second top bit */ 0x40 | /* Set top bit */ 0x80;
		bytesUsed = 2;
	} else if (ich <= 0xFFFF) {
		ret[0] = cast(ubyte)ch & /* Clear forth top bit */ ~10 | /* Set third upper bits */ 0xE0;
		ret[1] = cast(ubyte)(ch >> 4) | /* Clear second top bit */ 0x40 | /* Set top bit */ 0x80;
		ret[2] = cast(ubyte)(ch >> (4 + 6)) | /* Clear second top bit */ 0x40 | /* Set top bit */ 0x80;
		bytesUsed = 3;
	} else if (ich <= 0x10FFFF) {
		ret[0] = cast(ubyte)ch & /* Clear fifth top bit */ ~8 | /* Set forth upper bits */ 0xF0;
		ret[1] = cast(ubyte)(ch >> 3) | /* Clear second top bit */ 0x40 | /* Set top bit */ 0x80;
		ret[2] = cast(ubyte)(ch >> (3 + 6)) | /* Clear second top bit */ 0x40 | /* Set top bit */ 0x80;
		ret[3] = cast(ubyte)(ch >> (3 + 6 + 6)) | /* Clear second top bit */ 0x40 | /* Set top bit */ 0x80;
		bytesUsed = 4;
	} else // invalid size
		return toUTF8(dchar.init, bytesUsed);

	return ret;
}

struct UTF8Range {
	ubyte[] str;
	size_t bytesUsed;
	dchar current;

	this(ubyte[] str) {
		this.str = str;
		this.current = parseUTF8(str, bytesUsed);
	}

	@property dchar front() const {
		return current;
	}

	void popFront() {
		str = str[bytesUsed .. $];
		if (str.length)
			current = parseUTF8(str, bytesUsed);
		else
			current = dchar.init;
	}

	void popFrontN(size_t n) {
		while (n--)
			popFront();
	}

	dchar opIndex(size_t index) {
		ubyte[] str = this.str;
		size_t bytesUsed;
		dchar ch;
		while (str.length && index--) {
			ch = parseUTF8(str, bytesUsed);
			str = str[bytesUsed .. $];
		}
		if (index)
			ch = dchar.init;
		return ch;
	}

	@property bool empty() const {
		return !str.length;
	}

	@property size_t length() {
		ubyte[] str = this.str;
		size_t bytesUsed;
		size_t count;
		while (str.length) {
			parseUTF8(str, bytesUsed);
			str = str[bytesUsed .. $];
			count++;
		}
		return count;
	}

	@property UTF8Range save() {
		return UTF8Range(str);
	}

}
