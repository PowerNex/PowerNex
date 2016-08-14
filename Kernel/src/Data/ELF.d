module Data.ELF;

import Data.BitField;
import Data.Address;
import Data.String;
import IO.FS.FileNode;
import IO.Log;
import Data.TextBuffer : scr = GetBootTTY;

struct ELF64Header {
	struct Identification {
		char[4] magic;

		enum Class : ubyte {
			None,
			_32,
			_64
		}

		Class class_;

		enum Data : ubyte {
			None,
			LeastSignificantBit,
			MostSignificantBit
		}

		Data data;

		enum ELFVersion : ubyte {
			None,
			Current
		}

		ELFVersion elfVersion;

		enum OSABI : ubyte {
			None,
			PowerNex = 16
		}

		OSABI osABI;

		enum ABIVersion : ubyte {
			Current = 0
		}

		ABIVersion abiVersion;

		private char[7] pad;
	}

	static assert(Identification.sizeof == 16);
	Identification identification;

	enum ObjectType : ushort {
		None,
		Relocatable,
		Executable,
		Shared,
		Core
	}

	ObjectType type;

	enum Machine : ushort {
		None,
		I386 = 3,
		AMD64 = 0x3E
	}

	Machine machine;

	uint fileVersion;
	VirtAddress entry;
	VirtAddress programHeaderOffset;
	VirtAddress sectionHeaderOffset;
	private uint flags; // not used
	ushort elfHeaderSize;
	ushort programHeaderEntrySize;
	ushort programHeaderCount;
	ushort sectionHeaderEntrySize;
	ushort sectionHeaderCount;
	ushort sectionHeaderStringTableIndex;

	@property bool Valid() {
		immutable char[4] ELF64Magic = [0x7F, 'E', 'L', 'F'];
		return identification.magic == ELF64Magic;
	}
}

struct ELF64ProgramHeader {
	enum Type : uint {
		Null,
		Load,
		Dynamic,
		Interpreter,
		Note,
		SHLIB, // Not use, Not allowed
		ProgramHeader,
		ThreadLocalStorage,

		GNUEHFrameHeader = 0x6474E550,
		GNUStack = 0x6474E551,

	}

	Type type;

	enum Flags : uint {
		None,
		X = 1 << 0,
		W = 1 << 1,
		R = 1 << 2,

		WX = W | X,
		RX = R | X,
		RW = R | W,
		RWX = R | W | X
	}

	Flags flags;
	VirtAddress offset;
	VirtAddress virtAddress;
	PhysAddress physAddress;
	ulong fileSize;
	ulong memorySize;
	ulong align_;
}

struct ELF64SectionHeader {
	uint nameIdx;

	enum Type : uint {
		Null,
		ProgramBits,
		SymbolTable,
		StringTable,
		RelocationEntries,
		SymbolHashTable,
		DynamicLinking,
		Note,
		NoBits,
		RelocationOffsets,
		SHLIB, // Not used, not allowed
		DynamicLinkingSymbols,
		ConstructorArray = 14,
		DestructorArray,
		PreConstructorArray,
		GNUHashTable = 0x6FFFFFF6,
		GNUVersionNeeds = 0x6FFFFFFE,
		GNUVersionSymbolTable = 0x6FFFFFFF,
	}

	Type type;

	enum Flags : ulong {
		Null,
		Write = 1 << 0,
		Allocate = 1 << 1,
		ExecutableInstructions = 1 << 2,
		Merge = 1 << 4,
		Strings = 1 << 5,
		InfoLink = 1 << 6,
		LinkOrder = 1 << 7,
		Group = 1 << 9,
		ThreadLocalData = 1 << 10,
		Compressed = 1 << 11,

		Allocate_Write = Allocate | Write,
		ExecutableInstructions_Allocate = ExecutableInstructions | Allocate,
		Strings_Merge = Strings | Merge,
		InfoLink_Allocate = InfoLink | Allocate,
		ThreadLocalData_Allocate_Write = ThreadLocalData | Allocate | Write
	}

	Flags flags;
	VirtAddress address;
	VirtAddress offset;
	ulong size;
	uint link;
	uint info;
	ulong addressAlign;
	ulong entrySize;
}

struct ELF64Symbol {
	uint name;
	struct Info {
		enum InfoType : ubyte {
			NoType,
			Object,
			Function,
			Section,
			File,
			Common,
			TLS
		}

		enum InfoBinding : ubyte {
			Local,
			Global,
			Weak
		}

		private ubyte data;
		@property InfoType Type() {
			return cast(InfoType)(data & 0xF);
		}

		@property InfoType Type(InfoType type) {
			data = data & 0xF0 | type & 0xF;
			return type;
		}

		@property InfoBinding Binding() {
			return cast(InfoBinding)((data & 0xF0 >> 4) & 0x2);
		}

		@property InfoBinding Binding(InfoBinding binding) {
			data = (binding << 4) & 0xF0 | data & 0xF;
			return binding;
		}
	}

	Info info;
	enum Other : ubyte {
		Default,
		Internal,
		Hidden,
		Protected
	}

	Other other;
	ushort sectionIndex;
	VirtAddress value;
	ulong size;
}

struct ELF64Relocation {
	VirtAddress offset;
	struct Info {
		uint sym;
		uint type;
	}

	Info info;
}

struct ELF64RelocationAddend {
	VirtAddress offset;
	struct Info {
		uint sym;
		uint type;
	}

	Info info;
	int addend;
}

struct ELF64Dynamic {
	enum Tag : long {
		Null,
		Needed,
		PLTRelocationEntries,
		PLTGOT,
		HashTable,
		StringTable,
		SymbolTable,
		RelocationAddendTable,
		RelocationAddendTableSize,
		RelocationAddendTableEntrySize,
		StringTableSize,
		SymbolTableEntrySize,
		Init,
		Fini,
		SOName,
		RPath,
		Symbolic,
		RelocationTable,
		RelocationTableSize,
		RelocationTableEntrySize,
		PLTRel,
		Debug,
		TextRel,
		JumpRel,
		BindNow,
		RunPath
	}

	Tag tag;
	VirtAddress valueOrAddress;
}

class ELF {
public:
	this(FileNode file) {
		import IO.FS.Initrd.FileNode;

		this.file = file;

		if (file.Size < ELF64Header.sizeof)
			return;

		file.Read((cast(ubyte*)&header)[0 .. ELF64Header.sizeof], 0);
		if (!header.Valid)
			return;

		programHeaders.length = header.programHeaderCount;
		for (ulong idx = 0; idx < programHeaders.length; idx++)
			file.Read((cast(ubyte*)&programHeaders[idx])[0 .. ELF64ProgramHeader.sizeof],
					header.programHeaderOffset + header.programHeaderEntrySize * idx);

		ulong symtabIdx = ulong.max;

		sectionHeaders.length = header.sectionHeaderCount;
		for (ulong idx = 0; idx < sectionHeaders.length; idx++) {
			file.Read((cast(ubyte*)&sectionHeaders[idx])[0 .. ELF64SectionHeader.sizeof],
					header.sectionHeaderOffset + header.sectionHeaderEntrySize * idx);
			if (sectionHeaders[idx].type == ELF64SectionHeader.Type.SymbolTable)
				symtabIdx = idx;
			if (sectionHeaders[idx].type == ELF64SectionHeader.Type.StringTable)
				strtabIdx = idx;
		}

		if (symtabIdx != ulong.max) {
			ELF64SectionHeader symtab = sectionHeaders[symtabIdx];
			symbols.length = symtab.size / ELF64Symbol.sizeof;
			for (ulong idx = 0; idx < symbols.length; idx++)
				file.Read((cast(ubyte*)&symbols[idx])[0 .. ELF64Symbol.sizeof], symtab.offset + idx * ELF64Symbol.sizeof);
		}

		valid = true;
	}

	void Map() {
		import Memory.Paging;
		import Task.Scheduler;
		Scheduler scheduler = GetScheduler;
		Paging paging = scheduler.CurrentProcess.threadState.paging;

		foreach (idx, ELF64ProgramHeader* program; programHeaders) {
			scr.Writeln("Mapping #", idx);
		}
	}

	void Run() {

	}



	char[] GetSectionName(uint idx) {
		char[255] buf;
		if (!header.sectionHeaderStringTableIndex)
			return cast(char[])"UNKNOWN";

		file.Read(cast(ubyte[])buf, sectionHeaders[header.sectionHeaderStringTableIndex].offset + idx);

		return buf[0 .. strlen(buf)].dup;
	}

	char[] GetSymbolName(uint idx) {
		char[255] buf;
		if (!strtabIdx)
			return cast(char[])"UNKNOWN";

		file.Read(cast(ubyte[])buf, sectionHeaders[strtabIdx].offset + idx);

		return buf[0 .. strlen(buf)].dup;
	}

	@property bool Valid() {
		return valid;
	}

	@property ELF64Header Header() {
		return header;
	}

	@property ELF64ProgramHeader[] ProgramHeaders() {
		return programHeaders;
	}

	@property ELF64SectionHeader[] SectionHeaders() {
		return sectionHeaders;
	}

	@property ELF64Symbol[] Symbols() {
		return symbols;
	}

private:
	FileNode file;
	bool valid;
	ELF64Header header;
	ELF64ProgramHeader[] programHeaders;
	ELF64SectionHeader[] sectionHeaders;
	ulong strtabIdx;
	ELF64Symbol[] symbols;
}
