module Data.BMPImage;

import IO.FS.FileNode;
import HW.BGA.BGA;

private align(1) struct FileHeader {
align(1):
	char[2] filetype; /* magic - always 'B' 'M' */
	uint filesize;
	short reserved1;
	short reserved2;
	uint dataoffset; /* offset in bytes to actual bitmap data */
}

private align(1) struct BitmapHeader {
align(1):
	FileHeader fileheader;
	uint headersize;
	int width;
	int height;
	short planes;
	short bitsperpixel;
	uint compression;
	uint bitmapsize;
	int horizontalres;
	int verticalres;
	uint numcolors;
	uint importantcolors;
}

import IO.Log;

class BMPImage {
public:
	this(FileNode file) {
		file.Read((cast(ubyte*)&bitmap)[0 .. BitmapHeader.sizeof], 0);
		data = new Color[bitmap.width * bitmap.height];
		size_t offset = bitmap.fileheader.dataoffset - 1;
		int pad = (bitmap.width % 4);

		import IO.FS.Initrd.FileNode : InitrdFileNode;

		if (auto f = cast(InitrdFileNode)file) {
			ubyte[] d = f.RawAccess;
			for (int y = bitmap.height - 1; y >= 0; y--) {
				for (int x = 0; x < bitmap.width; x++, offset += 4)
					data[y * bitmap.width + x] = Color(d[offset + 0], d[offset + 1], d[offset + 2], d[offset + 3]);

				if (pad)
					offset = (offset + 4) & ~0b11;
			}
			return;
		}

		for (int y = bitmap.height - 1; y >= 0; y--) {
			for (int x = 0; x < bitmap.width; x++) {
				ubyte[4] abgr;
				file.Read(abgr, offset += 4);
				data[y * bitmap.width + x] = Color(abgr[0], abgr[1], abgr[2], abgr[3]); //Color(r, g, b, a);
			}
			if (pad)
				offset = (offset + 4) & ~0b11;
		}
	}

	~this() {
		data.destroy;
	}

	@property Color[] Data() {
		return data;
	}

	@property int Width() {
		return bitmap.width;
	}

	@property int Height() {
		return bitmap.height;
	}

private:
	BitmapHeader bitmap;
	Color[] data;
}
