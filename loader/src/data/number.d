module data.number;

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
	asm pure nothrow {
		bsr RAX, value;
		mov result, RAX;
	}

	//2 ^ result == value means value is a power of 2 and we dont need to round up
	if (1 << result != value)
		result++;

	return result;
}
