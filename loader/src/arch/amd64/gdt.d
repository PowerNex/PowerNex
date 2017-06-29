module arch.amd64.gdt;
//import data.bitfield;
//import cpu.tss;

///
align(1) @trusted struct GDTBase {
align(1):
	ushort limit; ///
	ulong base; ///
}

///
@trusted struct GDTCodeDescriptor {
align(1):
	import data.bitfield;

	ushort limit = 0xFFFF; ///
	ushort base = 0x0000; ///
	ubyte baseMiddle = 0x00; ///
	private ubyte flags1 = 0b11111101;
	private ubyte flags2 = 0b00000000;
	ubyte baseHigh = 0x00; ///

	mixin(bitfield!(flags1, "zero3", 2, "c", 1, "ones0", 2, "dpl", 2, "p", 1));
	mixin(bitfield!(flags2, "zero4", 5, "l", 1, "d", 1, "granularity", 1));
}

///
@trusted struct GDTDataDescriptor {
align(1):
	import data.bitfield;

	ushort limit = 0xFFFF; ///
	ushort base = 0x0000; ///
	ubyte baseMiddle = 0x00; ///
	private ubyte flags1 = 0b11110011;
	private ubyte flags2 = 0b11001111;
	ubyte baseHigh = 0x00; ///

	mixin(bitfield!(flags1, "zero4", 5, "dpl", 2, "p", 1));
}

///
@trusted struct GDTSystemDescriptor {
align(1):
	import data.bitfield;

	ushort limitLow; ///
	ushort baseLow; ///
	ubyte baseMiddleLow; ///
	private ubyte flags1;
	private ubyte flags2;
	ubyte baseMiddleHigh; ///

	mixin(bitfield!(flags1, "type", 4, "zero0", 1, "dpl", 2, "p", 1));
	mixin(bitfield!(flags2, "limitHigh", 4, "avl", 1, "zero1", 2, "g", 1));
}

///
@trusted struct GDTSystemExtension {
align(1):
	uint baseHigh; ///
	private uint reserved;
}

///
@trusted union GDTDescriptor {
align(1):
	GDTDataDescriptor data; ///
	GDTCodeDescriptor code; ///
	GDTSystemDescriptor systemLow; ///
	GDTSystemExtension systemHigh; ///

	//TSSDescriptor1 tss1;///
	//TSSDescriptor2 tss2;///

	ulong value; ///
}

static assert(GDTDescriptor.sizeof == ulong.sizeof);

///
enum GDTSystemType : ubyte {
	localDescriptorTable = 0b0010, ///
	availableTSS = 0b1001, ///
	busyTSS = 0b1011, ///
	callGate = 0b1100, ///
	interruptGate = 0b1110, ///
	trapGate = 0b1111 ///
}

private extern (C) void cpuRefreshIREQ();

private extern extern (C) __gshared GDTBase gdtBase;
private extern extern (C) __gshared GDTDescriptor[256] gdtDescriptors;

///
@safe static struct GDT {
public static:
	//__gshared TSS tss;///
	//__gshared ushort tssID;///

	///
	void init() {
		gdtBase.limit = cast(ushort)(_setupTable() * GDTDescriptor.sizeof - 1);
		gdtBase.base = cast(ulong)gdtDescriptors.ptr;

		flush();
	}

	///
	void flush() @trusted {
		// NOTE: Needs '.' because it need to grab the extern variable not the @property function.
		void* baseAddr = cast(void*)(&.gdtBase);
		//ushort id = cast(ushort)(tssID * GDTDescriptor.sizeof);
		asm pure nothrow {
			mov RAX, baseAddr;
			lgdt [RAX];
			call cpuRefreshIREQ;
			//ltr id;
		}
	}

	///
	void setNull(size_t index) {
		gdtDescriptors[index].value = 0;
	}

	///
	void setCode(size_t index, bool conforming, ubyte dpl_, bool present) {
		gdtDescriptors[index].code = GDTCodeDescriptor.init;
		with (gdtDescriptors[index].code) {
			c = conforming;
			dpl = dpl_;
			p = present;
			l = true;
			d = false;
		}
	}

	///
	void setData(uint index, bool present, ubyte dpl_) {
		gdtDescriptors[index].data = GDTDataDescriptor.init;
		with (gdtDescriptors[index].data) {
			p = present;
			dpl = dpl_;
		}
	}

	/*///
	void setTSS(uint index, ref TSS tss) {
		gdtDescriptors[index].tss1 = TSSDescriptor1(tss);
		gdtDescriptors[index + 1].tss2 = TSSDescriptor2(tss);
	}*/

	///
	void setSystem(uint index, uint limit, ulong base, GDTSystemType segType, ubyte dpl_, bool present, bool avail, bool granularity) {
		gdtDescriptors[index].systemLow = GDTSystemDescriptor.init;
		gdtDescriptors[index + 1].systemHigh = GDTSystemExtension.init;

		with (gdtDescriptors[index].systemLow) {
			baseLow = (base & 0xFFFF);
			baseMiddleLow = (base >> 16) & 0xFF;
			baseMiddleHigh = (base >> 24) & 0xFF;

			limitLow = limit & 0xFFFF;
			limitHigh = (limit >> 16) & 0xF;

			type = segType;
			dpl = dpl_;
			p = present;
			avl = avail;
			g = granularity;
		}

		gdtDescriptors[index + 1].systemHigh.baseHigh = (base >> 32) & 0xFFFFFFFF;
	}

	@property ref GDTBase gdtBase() @trusted {
		return .gdtBase;
	}

	@property ref GDTDescriptor[256] gdtDescriptors() @trusted {
		return .gdtDescriptors;
	}

private static:
	ushort _setupTable() {
		ushort idx = 0;
		setNull(idx++);
		// Kernel
		setCode(idx++, false, 0, true);
		setData(idx++, true, 0);

		// User
		setCode(idx++, true, 3, true);
		setData(idx++, true, 3);
		setCode(idx++, true, 3, true); // This is need because (MSR_STAR.SYSRET_CS + 16) is the CS when returning to 64bit mode.

		/*tssID = idx;
		setTSS(idx, tss); // Uses 2 entries
		idx += 2;*/
		return idx;
	}
}
