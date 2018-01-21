module data.psf;

import fs;
import memory.ptr;
import data.font;
import data.utf;

private enum {
	psf2Magic0 = 0x72,
	psf2Magic1 = 0xb5,
	psf2Magic2 = 0x4a,
	psf2Magic3 = 0x86,

	/* bits used in flags */
	psf2HasUnicodeTable = 0x01,

	/* max version recognized so far */
	psf2MaxVersion = 0,

	/* UTF8 separators */
	psf2Separator = 0xFF,
	psf2Startseq = 0xFE
}

private struct PSF2Header {
	ubyte[4] magic;
	uint version_;
	uint headersize; /* offset of bitmaps in file */
	uint flags;
	uint length; /* number of glyphs */
	uint charsize; /* number of bytes for each character */
	uint height, width; /* max dimensions of glyphs */
	/* charsize = height * ((width + 7) / 8) */
}

class PSF : Font {
public:
	this(SharedPtr!VNode file) {
		NodeContext nc;
		if ((*file).open(nc, FileDescriptorMode.read))
			return;

		_valid = read(*file, nc, _hdr) == IOStatus.success;
		if (!_valid)
			return;

		_valid = (_hdr.magic[0] == psf2Magic0 && _hdr.magic[1] == psf2Magic1 && _hdr.magic[2] == psf2Magic2 && _hdr.magic[3] == psf2Magic3);
		if (!_valid)
			return;

		_fontData = new ubyte[_hdr.charsize * _hdr.length];
		nc.offset = _hdr.headersize;
		_valid = (*file).read(nc, _fontData) == IOStatus.success;
		if (!_valid)
			return;

		_unicodeTable = new ubyte[(*file).size - _hdr.headersize - _fontData.length];
		nc.offset = _hdr.headersize + _fontData.length;
		_valid = (*file).read(nc, _unicodeTable) == IOStatus.success;
		if (!_valid)
			return;

		_parseUnicode();
	}

	this(ubyte[] file) {
		if (file.length < PSF2Header.sizeof)
			return;
		_hdr = *cast(PSF2Header*)file.ptr;

		_valid = (_hdr.magic[0] == psf2Magic0 && _hdr.magic[1] == psf2Magic1 && _hdr.magic[2] == psf2Magic2 && _hdr.magic[3] == psf2Magic3);
		if (!_valid)
			return;

		if (_hdr.charsize * _hdr.length + _hdr.headersize > file.length)
			return;
		_fontData = file[_hdr.headersize .. _hdr.headersize + _hdr.charsize * _hdr.length];
		_unicodeTable = file[_hdr.headersize + _hdr.charsize * _hdr.length .. $];

		_valid = true;
		_parseUnicode();
	}

	bool valid() {
		return _valid;
	}

	ref ulong[] getChar(dchar ch, ref return ulong[] buffer) {
		import io.log;

		foreach (ref row; buffer)
			row = 0;

		if (buffer.length < _hdr.height)
			return buffer;

		if (ch >= _maxChars || ch == dchar.init)
			ch = 0;

		dchar[_maxRendererPart] parts;
		if (auto id = _charJumpTable[ch])
			parts = _renderer[id];
		else
			parts[0] = ch;

		size_t widthBytes = (_hdr.width + 7) / 8;
		foreach (partId; parts) {
			if (partId == dchar.init)
				break;
			size_t partOffset = partId * _hdr.charsize;
			if (partOffset + widthBytes * _hdr.height >= _fontData.length)
				continue;
			foreach (row; 0 .. _hdr.height) {
				ulong bitmapRow;
				for (size_t partByte = 0; partByte < widthBytes; partByte++)
					bitmapRow = bitmapRow << 8 | _fontData[partOffset + row * widthBytes + partByte];

				buffer[row] |= bitmapRow;
			}
		}

		return buffer;
	}

	@property size_t bufferSize() {
		return _hdr.height;
	}

	@property uint width() {
		return _hdr.width; //TODO: Hack space between font here later?
	}

	@property uint height() {
		return _hdr.height;
	}

private:
	bool _valid;
	PSF2Header _hdr;
	ubyte[] _fontData;
	ubyte[] _unicodeTable;

	enum _maxChars = 0x10000;
	enum _maxRenderer = _maxChars;
	enum _maxRendererPart = 4;
	dchar[_maxRendererPart][_maxRenderer] _renderer; // How to render a char
	ushort[_maxChars] _charJumpTable; // Which renderer should be used to render the char
	ushort _rendererCount;

	void _parseUnicode() {
		size_t idx;

		// TODO: Fix. Totally wrong!
		if (false && _hdr.flags & psf2HasUnicodeTable && _unicodeTable.length) {
			while (_unicodeTable.length) {
				import io.log;

				while (_unicodeTable.length && _unicodeTable[0] != psf2Startseq) {
					if (_unicodeTable[0] == psf2Separator)
						break;

					size_t bytesUsed;
					auto ch = parseUTF8(_unicodeTable, bytesUsed);
					if (ch < _maxChars)
						_charJumpTable[ch] = _rendererCount;
					_unicodeTable = _unicodeTable[bytesUsed .. $];
					idx += bytesUsed;
				}
				if (_unicodeTable.length)
					_unicodeTable = _unicodeTable[1 .. $];

				size_t rendererPart;
				while (_unicodeTable.length && _unicodeTable[0] != psf2Separator) {
					if (rendererPart == _maxRendererPart) {
						while (_unicodeTable.length && _unicodeTable[0] != psf2Separator)
							_unicodeTable = _unicodeTable[1 .. $];
						break;
					}

					size_t bytesUsed;
					_renderer[_rendererCount][rendererPart++] = parseUTF8(_unicodeTable, bytesUsed);
					_unicodeTable = _unicodeTable[bytesUsed .. $];
					idx += bytesUsed;
				}

				_rendererCount++;
				if (_unicodeTable.length)
					_unicodeTable = _unicodeTable[1 .. $];
			}
		}
	}

}
