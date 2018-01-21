module data.font;

interface Font {
	@property size_t bufferSize();
	ref ulong[] getChar(dchar ch, ref return ulong[] buffer);
	@property uint width();
	@property uint height();
}
