module Data.Font;

interface Font {
	ulong[] GetChar(dchar ch);
	@property uint Width();
	@property uint Height();
}
