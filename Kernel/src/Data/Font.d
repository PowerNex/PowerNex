module Data.Font;

interface Font {
	ubyte[] GetChar(size_t ch);
	@property uint Width();
	@property uint Height();
}
