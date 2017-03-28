module Data.BMPImage;

import IO.FS.FileNode;
import Data.Color;

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
	uint redmask;
	uint greenmask;
	uint bluemask;
	uint alphamask;
}

import IO.Log;

class BMPImage {
public:
	this(FileNode file) {
		file.Read((cast(ubyte*)&bitmap)[0 .. BitmapHeader.sizeof], 0);
		data = new Color[bitmap.width * bitmap.height];
		size_t offset = bitmap.fileheader.dataoffset;
		int pad = bitmap.width % 4;

		switch (bitmap.bitsperpixel) {
		case 32:
			readData!32(file, offset, pad);
			break;
		case 24:
			readData!24(file, offset, pad);
			break;
		default:
			log.Error("Can't handle bpp = ", bitmap.bitsperpixel);
			return;
		}
	}

	this(BMPImage other) {
		bitmap = other.bitmap;
		data = other.Data.dup;
	}

	~this() {
		data.destroy;
	}

	@property BitmapHeader Header() {
		return bitmap;
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

	void readData(int bpp)(FileNode file, size_t offset, int pad) if (bpp == 24 || bpp == 32) {
		enum bytesPerPixel = bpp / 8;

		ubyte toIdx(int bitmask) {
			return (bitmask & 0x1_00_00_00) ? 3 : (bitmask & 0x00_01_00_00) ? 2 : (bitmask & 0x00_00_01_00) ? 1
				: (bitmask & 0x00_00_00_01) ? 0 : ubyte.max;
		}

		import IO.FS.Initrd.FileNode : InitrdFileNode;

		immutable ubyte rid = toIdx(bitmap.redmask);
		immutable ubyte gid = toIdx(bitmap.greenmask);
		immutable ubyte bid = toIdx(bitmap.bluemask);
		immutable ubyte aid = toIdx(bitmap.alphamask);

		log.Debug("rid: ", cast(int)rid, " gid: ", cast(int)gid, " bid: ", cast(int)bid, " aid: ", cast(int)aid);

		ubyte[bytesPerPixel] buf = void;
		for (int y = bitmap.height - 1; y >= 0; y--) {
			for (int x = 0; x < bitmap.width; x++) {
				file.Read(buf, offset);
				offset += bytesPerPixel;

				immutable ubyte r = rid != ubyte.max ? buf[rid] : 0;
				immutable ubyte g = gid != ubyte.max ? buf[gid] : 0;
				immutable ubyte b = bid != ubyte.max ? buf[bid] : 0;

				static if (bpp == 32)
					immutable ubyte a = aid != ubyte.max ? buf[aid] : 255;
				else
					immutable ubyte a = 0;

				data[y * bitmap.width + x] = Color(r, g, b, a);
			}

			if (pad)
				offset = (offset + 4) & ~0b11;
		}
	}
}

/*
if (auto f = cast(InitrdFileNode)file) {
				ubyte[] d = f.RawAccess;
				for (int y = bitmap.height - 1; y >= 0; y--) {
					for (int x = 0; x < bitmap.width; x++, offset += bytesPerPixel) {
						data[y * bitmap.width + x] = Color(d[offset + 0], d[offset + 1], d[offset + 2], d[offset + 3]);
					}

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
*/
