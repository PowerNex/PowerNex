module HW.BGA.PSF;

import Data.Font;
import Data.UTF;
import IO.FS.FileNode;

private enum {
	PSF2_MAGIC0 = 0x72,
	PSF2_MAGIC1 = 0xb5,
	PSF2_MAGIC2 = 0x4a,
	PSF2_MAGIC3 = 0x86,

	/* bits used in flags */
	PSF2_HAS_UNICODE_TABLE = 0x01,

	/* max version recognized so far */
	PSF2_MAXVERSION = 0,

	/* UTF8 separators */
	PSF2_SEPARATOR = 0xFF,
	PSF2_STARTSEQ = 0xFE,
}

private struct psf2_header {
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
	this(FileNode file) {
		valid = read(file, hdr);
		if (!valid)
			return;

		valid = (hdr.magic[0] == PSF2_MAGIC0 && hdr.magic[1] == PSF2_MAGIC1 && hdr.magic[2] == PSF2_MAGIC2 && hdr.magic[3] == PSF2_MAGIC3);
		if (!valid)
			return;

		fontData = new ubyte[hdr.charsize * hdr.length];
		valid = file.Read(fontData, hdr.headersize) == fontData.length;
		if (!valid)
			return;

		unicodeTable = new ubyte[file.Size - hdr.headersize - fontData.length];
		valid = file.Read(unicodeTable, hdr.headersize + fontData.length) == unicodeTable.length;
		if (!valid)
			return;

		bitmapOfChar = new ulong[hdr.height];
		parseUnicode();
	}

	this(ubyte[] file) {
		if (file.length < psf2_header.sizeof)
			return;
		hdr = *cast(psf2_header*)file.ptr;

		valid = (hdr.magic[0] == PSF2_MAGIC0 && hdr.magic[1] == PSF2_MAGIC1 && hdr.magic[2] == PSF2_MAGIC2 && hdr.magic[3] == PSF2_MAGIC3);
		if (!valid)
			return;

		if (hdr.charsize * hdr.length + hdr.headersize > file.length)
			return;
		fontData = file[hdr.headersize .. hdr.headersize + hdr.charsize * hdr.length];
		unicodeTable = file[hdr.headersize + hdr.charsize * hdr.length .. $];

		valid = true;
		bitmapOfChar = new ulong[hdr.height];
		parseUnicode();
	}

	bool Valid() {
		return valid;
	}

	ulong[] GetChar(dchar ch) {
		import IO.Log;

		//ulong[] bitmapOfChar = new ulong[hdr.height];
		foreach (ref row; bitmapOfChar)
			row = 0;

		if (ch >= MAX_CHARS)
			return bitmapOfChar;

		dchar[MAX_RENDERER_PART] parts;
		if (auto id = charJumpTable[ch])
			parts = renderer[id];
		else
			parts[0] = ch;

		size_t widthBytes = (hdr.width + 7) / 8;
		foreach (partId; parts) {
			if (partId == dchar.init)
				break;
			size_t partOffset = partId * hdr.charsize;
			if (partOffset + widthBytes * hdr.height >= fontData.length)
				continue;
			foreach (row; 0 .. hdr.height) {
				ulong bitmapRow;
				for (size_t partByte = 0; partByte < widthBytes; partByte++)
					bitmapRow = bitmapRow << 8 | fontData[partOffset + row * widthBytes + partByte];

				bitmapOfChar[row] |= bitmapRow;
			}
		}

		return bitmapOfChar;
	}

	@property uint Width() {
		return hdr.width; //TODO: Hack space between font here later?
	}

	@property uint Height() {
		return hdr.height;
	}

private:
	bool valid;
	psf2_header hdr;
	ubyte[] fontData;
	ubyte[] unicodeTable;

	ulong[] bitmapOfChar;

	enum MAX_CHARS = 0x10000;
	enum MAX_RENDERER = MAX_CHARS;
	enum MAX_RENDERER_PART = 4;
	dchar[MAX_RENDERER_PART][MAX_RENDERER] renderer; // How to render a char
	ushort[MAX_CHARS] charJumpTable; // Which renderer should be used to render the char
	ushort rendererCount;

	bool read(T)(FileNode file, ref T t, ulong offset = 0) {
		return file.Read((cast(ubyte*)(&t))[0 .. T.sizeof], offset) == T.sizeof;
	}

	void parseUnicode() {
		size_t idx;

		// TODO: Fix. Totally wrong!
		if (false && hdr.flags & PSF2_HAS_UNICODE_TABLE && unicodeTable.length) {
			while (unicodeTable.length) {
				import IO.Log;

				while (unicodeTable.length && unicodeTable[0] != PSF2_STARTSEQ) {
					if (unicodeTable[0] == PSF2_SEPARATOR)
						break;

					size_t bytesUsed;
					auto ch = ParseUTF8(unicodeTable, bytesUsed);
					if (ch < MAX_CHARS)
						charJumpTable[ch] = rendererCount;
					unicodeTable = unicodeTable[bytesUsed .. $];
					idx += bytesUsed;
				}
				if (unicodeTable.length)
					unicodeTable = unicodeTable[1 .. $];

				size_t rendererPart;
				while (unicodeTable.length && unicodeTable[0] != PSF2_SEPARATOR) {
					if (rendererPart == MAX_RENDERER_PART) {
						while (unicodeTable.length && unicodeTable[0] != PSF2_SEPARATOR)
							unicodeTable = unicodeTable[1 .. $];
						break;
					}

					size_t bytesUsed;
					renderer[rendererCount][rendererPart++] = ParseUTF8(unicodeTable, bytesUsed);
					unicodeTable = unicodeTable[bytesUsed .. $];
					idx += bytesUsed;
				}

				rendererCount++;
				if (unicodeTable.length)
					unicodeTable = unicodeTable[1 .. $];
			}
		}
	}

}
