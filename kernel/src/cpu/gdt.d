module cpu.gdt;
import data.bitfield;

align(1) struct GDTBase {
align(1):
	ushort Limit;
	ulong Base;
}

struct GDTCodeDescriptor {
align(1):
	ushort Limit = 0xFFFF;
	ushort Base = 0x0000;
	ubyte BaseMiddle = 0x00;
	private ubyte flags1 = 0b11111101;
	private ubyte flags2 = 0b00000000;
	ubyte BaseHigh = 0x00;

	mixin(Bitfield!(flags1, "zero3", 2, "c", 1, "ones0", 2, "dpl", 2, "p", 1));
	mixin(Bitfield!(flags2, "zero4", 5, "l", 1, "d", 1, "Granularity", 1));
}

struct GDTDataDescriptor {
align(1):
	ushort Limit = 0xFFFF;
	ushort Base = 0x0000;
	ubyte BaseMiddle = 0x00;
	private ubyte flags1 = 0b11110011;
	private ubyte flags2 = 0b11001111;
	ubyte BaseHigh = 0x00;

	mixin(Bitfield!(flags1, "zero4", 5, "dpl", 2, "p", 1));
}

struct GDTSystemDescriptor {
align(1):
	ushort LimitLow;
	ushort BaseLow;
	ubyte BaseMiddleLow;
	private ubyte flags1;
	private ubyte flags2;
	ubyte BaseMiddleHigh;

	mixin(Bitfield!(flags1, "Type", 4, "Zero0", 1, "dpl", 2, "p", 1));
	mixin(Bitfield!(flags2, "LimitHigh", 4, "avl", 1, "Zero1", 2, "g", 1));
}

struct GDTSystemExtension {
align(1):
	uint BaseHigh;
	private uint reserved;
}

union GDTDescriptor {
align(1):
	GDTDataDescriptor Data;
	GDTCodeDescriptor Code;
	GDTSystemDescriptor SystemLow;
	GDTSystemExtension SystemHigh;

	ulong Value;
}

enum GDTSystemType : ubyte {
	LocalDescriptorTable = 0b0010,
	AvailableTSS = 0b1001,
	BusyTSS = 0b1011,
	CallGate = 0b1100,
	InterruptGate = 0b1110,
	TrapGate = 0b1111
}

private extern (C) void CPU_refresh_iretq();

static struct GDT {
public:
	__gshared GDTBase base;
	__gshared GDTDescriptor[256] descriptors;

	static void Init() {
		base.Limit = descriptors.length * GDTDescriptor.sizeof - 1;
		base.Base = cast(ulong)descriptors.ptr;

		setupTable();

		Flush();
	}

	static void Flush() {
		void* baseAddr = cast(void*)(&base);
		asm {
			mov baseAddr, RAX;
			lgdt [RAX];
			call CPU_refresh_iretq;
		}
	}

	static void SetNull(size_t index) {
		descriptors[index].Value = 0;
	}

	static void SetCode(size_t index, bool conforming, ubyte DPL, bool present) {
		descriptors[index].Code = GDTCodeDescriptor.init;
		with (descriptors[index].Code) {
			c = conforming;
			dpl = DPL;
			p = present;
			l = true;
			d = false;
		}
	}

	static void SetData(uint index, bool present, ubyte DPL) {
		descriptors[index].Data = GDTDataDescriptor.init;
		with (descriptors[index].Data) {
			p = present;
			dpl = DPL;
		}
	}

	void SetSystem(uint index, uint limit, ulong base, GDTSystemType segType, ubyte DPL, bool present, bool avail, bool granularity) {
		descriptors[index].SystemLow = GDTSystemDescriptor.init;
		descriptors[index + 1].SystemHigh = GDTSystemExtension.init;

		with (descriptors[index].SystemLow) {
			BaseLow = (base & 0xFFFF);
			BaseMiddleLow = (base >> 16) & 0xFF;
			BaseMiddleHigh = (base >> 24) & 0xFF;

			LimitLow = limit & 0xFFFF;
			LimitHigh = (limit >> 16) & 0xF;

			Type = segType;
			dpl = DPL;
			p = present;
			avl = avail;
			g = granularity;
		}

		descriptors[index + 1].SystemHigh.BaseHigh = (base >> 32) & 0xFFFFFFFF;
	}

private:
	static void setupTable() {
		SetNull(0);
		// Kernel
		SetCode(1, false, 0, true);
		SetData(2, true, 0);

		// User
		SetData(3, true, 3);
		SetCode(4, true, 3, true);
	}
}
