/**
 * This is a helper module for generation bitfields.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module data.bitfield;

///
template bitfield(alias data, args...) {
	enum bitfield = bitfieldShim!((typeof(data)).stringof, data, args).ret;
}

///
template bitfieldShim(const char[] typeStr, alias data, args...) {
	enum name = data.stringof;
	enum ret = bitfieldImpl!(typeStr, name, 0, args).ret;
}

///
template bitfieldImpl(const char[] typeStr, const char[] nameStr, int offset, args...) {
	static if (!args.length)
		enum ret = "";
	else static if (args.length == 1 && !args[0].length)
		enum ret = bitfieldImpl!(typeStr, nameStr, offset + args[1], args[2 .. $]).ret;
	else {
		enum name = args[0];
		enum size = args[1];
		enum mask = bitmask!size;
		static if (args.length > 2 && is(args[2])) {
			enum type = args[2].stringof;
			enum nextItemAt = 3;
		} else {
			enum type = targetType!size;
			enum nextItemAt = 2;
		}

		enum getter = "///\n@property " ~ type ~ " " ~ name ~ "() const { return cast(" ~ type ~ ")((" ~ nameStr ~ " >> " ~ itoh!(
					offset) ~ ") & " ~ itoh!(mask) ~ "); } \n";

		enum setter = "///\n@property void " ~ name ~ "(" ~ type ~ " val) { " ~ nameStr ~ " = (" ~ nameStr ~ " & " ~ itoh!(
					~(mask << offset)) ~ ") | ((val & " ~ itoh!(mask) ~ ") << " ~ itoh!(offset) ~ "); } \n";

		enum ret = getter ~ setter ~ bitfieldImpl!(typeStr, nameStr, offset + size, args[nextItemAt .. $]).ret;
	}
}

///
template bitmask(long size) {
	const long bitmask = (1UL << size) - 1;
}

///
template targetType(long size) {
	static if (size == 1)
		enum targetType = "bool";
	else static if (size <= 8)
		enum targetType = "ubyte";
	else static if (size <= 16)
		enum targetType = "ushort";
	else static if (size <= 32)
		enum targetType = "uint";
	else static if (size <= 64)
		enum targetType = "ulong";
	else
		static assert(0);
}

template itoh(long i) {
	enum itoh = "0x" ~ intToStr!(i, 16) ~ "UL";
}

template digits(long i) {
	enum digits = "0123456789abcdefghijklmnopqrstuvwxyz"[0 .. i];
}

template intToStr(ulong i, int base) {
	static if (i >= base)
		enum intToStr = intToStr!(i / base, base) ~ digits!base[i % base];
	else
		enum intToStr = "" ~ digits!base[i % base];
}
