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

		size_t offset = bitmap.fileheader.dataoffset;
		int pad = (bitmap.width % 4);

		for (int y = bitmap.height - 1; y >= 0; y--) {
			for (int x = 0; x < bitmap.width; x++) {
				ubyte r, g, b;
				offset++; //alpha
				file.Read((&b)[0 .. 1], offset++);
				file.Read((&g)[0 .. 1], offset++);
				file.Read((&r)[0 .. 1], offset++);

				data[y * bitmap.width + x] = Color(r, g, b);
			}
			if (pad)
				for (int i = 0; i < 4 - pad; i++)
					offset++;
		}
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
