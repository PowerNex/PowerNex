module data.bitfield;

template bitfield(alias data, args...) {
	const char[] bitfield = bitfieldShim!((typeof(data)).stringof, data, args).ret;
}

template bitfieldShim(const char[] typeStr, alias data, args...) {
	const char[] name = data.stringof;
	const char[] ret = bitfieldImpl!(typeStr, name, 0, args).ret;
}

template bitfieldImpl(const char[] typeStr, const char[] nameStr, int offset, args...) {
	static if (!args.length)
		const char[] ret = "";
	else static if (!args[0].length)
		const char[] ret = bitfieldImpl!(typeStr, nameStr, offset + args[1], args[2 .. $]).ret;
	else {
		const name = args[0];
		const size = args[1];
		const mask = bitmask!size;
		const type = targetType!size;

		const char[] getter = "@property " ~ type ~ " " ~ name ~ "() { return cast(" ~ type ~ ")((" ~ nameStr ~ " >> " ~ itoh!(
				offset) ~ ") & " ~ itoh!(mask) ~ "); } \n";

		const char[] setter = "@property void " ~ name ~ "(" ~ type ~ " val) { " ~ nameStr ~ " = (" ~ nameStr ~ " & " ~ itoh!(
				~(mask << offset)) ~ ") | ((val & " ~ itoh!(mask) ~ ") << " ~ itoh!(offset) ~ "); } \n";

		const char[] ret = getter ~ setter ~ bitfieldImpl!(typeStr, nameStr, offset + size, args[2 .. $]).ret;
	}
}

template bitmask(long size) {
	const long bitmask = (1UL << size) - 1;
}

template targetType(long size) {
	static if (size == 1)
		const targetType = "bool";
	else static if (size <= 8)
		const targetType = "ubyte";
	else static if (size <= 16)
		const targetType = "ushort";
	else static if (size <= 32)
		const targetType = "uint";
	else static if (size <= 64)
		const targetType = "ulong";
	else
		static assert(0);
}

template itoh(long i) {
	const char[] itoh = "0x" ~ intToStr!(i, 16) ~ "UL";
}

template digits(long i) {
	const char[] digits = "0123456789abcdefghijklmnopqrstuvwxyz"[0 .. i];
}

template intToStr(ulong i, int base) {
	static if (i >= base)
		const char[] intToStr = intToStr!(i / base, base) ~ digits!base[i % base];
	else
		const char[] intToStr = "" ~ digits!base[i % base];
}
