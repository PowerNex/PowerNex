module Data.BitField;

template Bitfield(alias data, Args...) {
	const char[] Bitfield = BitfieldShim!((typeof(data)).stringof, data, Args).Ret;
}

template BitfieldShim(const char[] typeStr, alias data, Args...) {
	const char[] Name = data.stringof;
	const char[] Ret = BitfieldImpl!(typeStr, Name, 0, Args).Ret;
}

template BitfieldImpl(const char[] typeStr, const char[] nameStr, int offset, Args...) {
	static if (!Args.length)
		const char[] Ret = "";
	else {
		const Name = Args[0];
		const Size = Args[1];
		const Mask = Bitmask!Size;
		const Type = TargetType!Size;

		const char[] Getter = "@property " ~ Type ~ " " ~ Name ~ "() { return cast(" ~ Type ~ ")((" ~ nameStr ~ " >> " ~ Itoh!(
				offset) ~ ") & " ~ Itoh!(Mask) ~ "); } \n";

		const char[] Setter = "@property void " ~ Name ~ "(" ~ Type ~ " val) { " ~ nameStr ~ " = (" ~ nameStr ~ " & " ~ Itoh!(
				~(Mask << offset)) ~ ") | ((val & " ~ Itoh!(Mask) ~ ") << " ~ Itoh!(offset) ~ "); } \n";

		const char[] Ret = Getter ~ Setter ~ BitfieldImpl!(typeStr, nameStr, offset + Size, Args[2 .. $]).Ret;
	}
}

template Bitmask(long size) {
	const long Bitmask = (1UL << size) - 1;
}

template TargetType(long size) {
	static if (size == 1)
		const TargetType = "bool";
	else static if (size <= 8)
		const TargetType = "ubyte";
	else static if (size <= 16)
		const TargetType = "ushort";
	else static if (size <= 32)
		const TargetType = "uint";
	else static if (size <= 64)
		const TargetType = "ulong";
	else
		static assert(0);
}

template Itoh(long i) {
	const char[] Itoh = "0x" ~ IntToStr!(i, 16) ~ "UL";
}

template Digits(long i) {
	const char[] Digits = "0123456789abcdefghijklmnopqrstuvwxyz"[0 .. i];
}

template IntToStr(ulong i, int base) {
	static if (i >= base)
		const char[] IntToStr = IntToStr!(i / base, base) ~ Digits!base[i % base];
	else
		const char[] IntToStr = "" ~ Digits!base[i % base];
}
