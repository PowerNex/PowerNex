module HW.BGA.PSF;

import Data.Font;
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

		data = new ubyte[hdr.charsize * hdr.length];
		valid = file.Read(data, hdr.headersize) == data.length;
	}

	bool Valid() {
		return valid;
	}

	ubyte[] GetChar(size_t ch) {
		size_t start = ch * hdr.height;
		if (start >= data.length || start + hdr.height > data.length)
			return [];
		return data[start .. start + hdr.height];
	}

	@property uint Width() {
		return hdr.width;
	}

	@property uint Height() {
		return hdr.height;
	}

private:
	bool valid;
	FileNode file;
	psf2_header hdr;
	ubyte[] data;

	bool read(T)(FileNode file, ref T t, ulong offset = 0) {
		return file.Read((cast(ubyte*)(&t))[0 .. T.sizeof], offset) == T.sizeof;
	}

}
