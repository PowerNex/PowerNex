module arch.amd64.bga;

import stl.address;

///
@safe align(1) struct Color {
align(1):
	ubyte b, g, r;
	private ubyte _ = 0;

	///
	this(ubyte r, ubyte g, ubyte b) {
		this.r = r;
		this.g = g;
		this.b = b;
	}

	static assert(Color.sizeof == uint.sizeof);
}

///
@safe static struct BGA {
static public:
	///
	void init(ushort width = 1920, ushort height = 1080, BGABPP bpp = BGABPP.bpp32) {
		import stl.io.log;
		import stl.arch.amd64.ioport;
		import hw.pci.pci;

		PCIDevice* device = () @trusted { return PCI.getDevice(0x1234, 0x1111); }();
		if (!device) {
			Log.error("BGA PCI device not found, aborting!");
			return;
		}

		PhysAddress videoMemory = PhysAddress(device.bar0 & ~0xF);

		// Force version 4
		_set(BGARegister.id, BGAVersions.ver4);

		setResolution(width, height, bpp, cast(ushort)(height * 4));

		// Aquire video memory size
		immutable size_t vgaSize = _get(BGARegister.videoMemory64K) * (64 * 1024);
		assert(Color.sizeof * width * height <= vgaSize, "Screen buffer takes up more space than what is allocated from the hardware.");

		for (PhysAddress page = videoMemory; page < videoMemory + vgaSize; page += 0x1000) {
			import arch.paging : mapAddress, VMPageFlags;

			assert(mapAddress(VirtAddress(page.num), page, VMPageFlags.present | VMPageFlags.writable), "Failed to map BGA memory");
		}

		() @trusted { _screen = VirtAddress(videoMemory.num).array!Color(width * height); }();
	}

	///
	void setResolution(ushort width, ushort height, BGABPP bpp, ushort virtHeight) @trusted {
		// Disable BGA before doing changes
		_set(BGARegister.enable, BGAEnabled.disable);

		// Update settings
		_set(BGARegister.xRes, width);
		_set(BGARegister.yRes, height);
		_set(BGARegister.bpp, bpp);
		_set(BGARegister.virtHeight, virtHeight);

		// Reenable BGA
		_set(BGARegister.enable, BGAEnabled.enable_lfbEnabled);

		// Acquire width and height in case the BGA backend chooses a different size
		_width = _get(BGARegister.xRes);
		_height = _get(BGARegister.yRes);
		_bpp = bpp;
		_virtHeight = virtHeight;
	}

	///
	@property ref ushort width() @trusted {
		return _width;
	}

	///
	@property ref ushort height() @trusted {
		return _height;
	}

	///
	@property ref ushort virtHeight() @trusted {
		return _virtHeight;
	}

	///
	@property ref BGABPP bpp() @trusted {
		return _bpp;
	}

	///
	@property Color[] screen() @trusted {
		return _screen;
	}

static private:
	enum BGARegister : ushort {
		id = 0,
		xRes = 1,
		yRes = 2,
		bpp = 3,
		enable = 4,
		bank = 5,
		virtWidth = 6,
		virtHeight = 7,
		xOffset = 8,
		yOffset = 9,
		videoMemory64K = 10
	}

	enum BGAVersions : ushort {
		ver0 = 0xB0C0, //setting X and Y resolution and bit depth (8 BPP only), banked mode
		ver1 = 0xB0C1, //virtual width and height, X and Y offset
		ver2 = 0xB0C2, //15, 16, 24 and 32 BPP modes, support for linear frame buffer, support for retaining memory contents on mode switching
		ver3 = 0xB0C3, //support for getting capabilities, support for using 8 bit DAC
		ver4 = 0xB0C4, //VRAM increased to 8 MB
		ver5 = 0xB0C5, //VRAM increased to 16 MB? [TODO: verify and check for other changes]
	}

	enum BGABPP : ushort {
		bpp4 = 4,
		bpp8 = 8,
		bpp15 = 15,
		bpp16 = 16,
		bpp24 = 24,
		bpp32 = 32,
	}

	enum BGAEnabled : ushort {
		disable = 0,
		enable = 1,
		lfbEnabled = 0x40,

		enable_lfbEnabled = enable | lfbEnabled,
	}

	enum ushort _bgaDisplayIOPortIndex = 0x01CE;
	enum ushort _bgaDisplayIOPortData = 0x01CF;

	__gshared ushort _width = 1920;
	__gshared ushort _height = 1080;
	__gshared ushort _virtHeight = 0;
	__gshared BGABPP _bpp = BGABPP.bpp32;

	__gshared Color[] _screen;

	void _set(T = ushort)(BGARegister reg, T value) if (T.sizeof == 2) {
		import stl.arch.amd64.ioport;

		outp!ushort(_bgaDisplayIOPortIndex, reg);
		outp!ushort(_bgaDisplayIOPortData, value);
	}

	T _get(T = ushort)(BGARegister reg) if (T.sizeof == 2) {
		import stl.arch.amd64.ioport;

		outp!ushort(_bgaDisplayIOPortIndex, reg);
		return inp!T(_bgaDisplayIOPortData);
	}
}
