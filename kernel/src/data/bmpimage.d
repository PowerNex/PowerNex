module data.bmpimage;

import io.fs.filenode;
import data.color;
import io.log;

private align(1) struct FileHeader {
align(1):
	char[2] fileType; /* magic - always 'B' 'M' */
	uint fileSize;
	short reserved1;
	short reserved2;
	uint dataOffset; /* offset in bytes to actual bitmap data */
}

private align(1) struct BitmapHeader {
align(1):
	FileHeader fileHeader;
	uint headerSize;
	int width;
	int height;
	short planes;
	short bitsPerPixel;
	uint compression;
	uint bitmapSize;
	int horizontalRes;
	int verticalRes;
	uint numColors;
	uint importantColors;
	uint redMask;
	uint greenMask;
	uint blueMask;
	uint alphaMask;
}

class BMPImage {
public:
	this(FileNode file) {
		file.read((cast(ubyte*)&_bitmap)[0 .. BitmapHeader.sizeof], 0);
		_data = new Color[_bitmap.width * _bitmap.height];
		size_t offset = _bitmap.fileHeader.dataOffset;
		int pad = _bitmap.width % 4;

		switch (_bitmap.bitsPerPixel) {
		case 32:
			_readData!32(file, offset, pad);
			break;
		case 24:
			_readData!24(file, offset, pad);
			break;
		default:
			log.error("Can't handle bpp = ", _bitmap.bitsPerPixel);
			return;
		}
	}

	this(BMPImage other) {
		_bitmap = other._bitmap;
		_data = other._data.dup;
	}

	~this() {
		_data.destroy;
	}

	@property BitmapHeader header() {
		return _bitmap;
	}

	@property Color[] data() {
		return _data;
	}

	@property int width() {
		return _bitmap.width;
	}

	@property int height() {
		return _bitmap.height;
	}

private:
	BitmapHeader _bitmap;
	Color[] _data;

	void _readData(int bpp)(FileNode file, size_t offset, int pad) if (bpp == 24 || bpp == 32) {
		enum bytesPerPixel = bpp / 8;

		ubyte toIdx(int bitmask) {
			return (bitmask & 0x1_00_00_00) ? 3 : (bitmask & 0x00_01_00_00) ? 2 : (bitmask & 0x00_00_01_00) ? 1
				: (bitmask & 0x00_00_00_01) ? 0 : ubyte.max;
		}

		import io.fs.initrd.filenode : InitrdFileNode;

		immutable ubyte rid = toIdx(_bitmap.redMask);
		immutable ubyte gid = toIdx(_bitmap.greenMask);
		immutable ubyte bid = toIdx(_bitmap.blueMask);
		immutable ubyte aid = toIdx(_bitmap.alphaMask);

		log.debug_("rid: ", cast(int)rid, " gid: ", cast(int)gid, " bid: ", cast(int)bid, " aid: ", cast(int)aid);

		ubyte[bytesPerPixel] buf = void;
		for (int y = _bitmap.height - 1; y >= 0; y--) {
			for (int x = 0; x < _bitmap.width; x++) {
				file.read(buf, offset);
				offset += bytesPerPixel;

				immutable ubyte r = rid != ubyte.max ? buf[rid] : 0;
				immutable ubyte g = gid != ubyte.max ? buf[gid] : 0;
				immutable ubyte b = bid != ubyte.max ? buf[bid] : 0;

				static if (bpp == 32)
					immutable ubyte a = aid != ubyte.max ? buf[aid] : 255;
				else
					immutable ubyte a = 0;

				_data[y * _bitmap.width + x] = Color(r, g, b, a);
			}

			if (pad)
				offset = (offset + 4) & ~0b11;
		}
	}
}
