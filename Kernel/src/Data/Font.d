module Data.Font;

interface Font {
	@property size_t BufferSize();
	ref ulong[] GetChar(dchar ch, ref return ulong[] buffer);
	@property uint Width();
	@property uint Height();
}
