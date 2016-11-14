module Data.ELF;

import Data.BitField;
import Data.Address;
import Data.String;
import IO.FS.FileNode;
import IO.Log;
import Data.TextBuffer : scr = GetBootTTY;
import Task.Process;
import Memory.Heap;

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
		return identification.magic == ELF64Magic && programHeaderEntrySize == ELF64ProgramHeader.sizeof
			&& ELF64SectionHeader.sizeof == sectionHeaderEntrySize;
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
		R = 1 << 2
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
		this.file = file;

		if (file.Size <= ELF64Header.sizeof)
			return;

		file.Read((cast(ubyte*)&header)[0 .. ELF64Header.sizeof], 0);
		valid = header.Valid;

		foreach (idx; 0 .. header.sectionHeaderCount) {
			ELF64SectionHeader sectionHdr = GetSectionHeader(idx);
			if (sectionHdr.type == ELF64SectionHeader.Type.SymbolTable)
				symtabIdx = idx;
			else if (sectionHdr.type == ELF64SectionHeader.Type.StringTable)
				strtabIdx = idx;
		}
	}

	void MapAndRun(string[] args) {
		import Memory.Paging;
		import Task.Scheduler;

		Scheduler scheduler = GetScheduler;
		Process* process = scheduler.CurrentProcess;
		Paging paging = process.threadState.paging;

		string[] tmpArgs;
		tmpArgs.length = args.length;
		foreach (idx, arg; args)
			tmpArgs[idx] = arg.dup;

		if (process.heap && !(--process.heap.RefCounter))
			process.heap.destroy;

		paging.RemoveUserspace(true);

		VirtAddress startHeap;

		foreach (idx; 0 .. header.programHeaderCount) {
			ELF64ProgramHeader program = GetProgramHeader(idx);
			if (program.type == ELF64ProgramHeader.Type.Load) {

				MapMode mode = MapMode.User;
				if (!(program.flags & ELF64ProgramHeader.Flags.X))
					mode |= MapMode.NoExecute;
				if (program.flags & ELF64ProgramHeader.Flags.W)
					mode |= MapMode.Writable;
				// Page will always be readable

				VirtAddress start = program.virtAddress & ~0xFFF;
				VirtAddress end = program.virtAddress + program.memorySize;
				VirtAddress cur = start;
				while (cur < end) {
					paging.MapFreeMemory(cur, MapMode.DefaultKernel);
					cur += 0x1000;
				}

				log.Debug("Start: ", start, " End: ", end, " cur: ", cur, " Mode: R", (mode & MapMode.Writable) ? "W"
						: "", (mode & MapMode.NoExecute) ? "" : "X", (mode & MapMode.User) ? "-User" : "");

				memset(start.Ptr, 0, (program.virtAddress - start).Int);
				cur = (program.virtAddress + program.fileSize);
				memset(cur.Ptr, 0, (end - cur).Int);
				file.Read(program.virtAddress.Ptr!ubyte[0 .. program.fileSize], program.offset.Int);

				cur = start;
				while (cur < end) {
					auto page = paging.GetPage(cur);
					page.Mode = mode;
					paging.FlushPage(cur);
					cur += 0x1000;
				}

				if (end > startHeap)
					startHeap = end;
			} else if (program.type == ELF64ProgramHeader.Type.ThreadLocalStorage)
				process.image.defaultTLS = program.virtAddress.Ptr!ubyte[0 .. program.memorySize];
		}

		// Setup stack, setup heap

		asm {
			cli;
		}

		startHeap = (startHeap.Int + 0xFFF) & ~0xFFF;

		process.heap = new Heap(process.threadState.paging, MapMode.DefaultUser, startHeap, VirtAddress(0xFFFF_FFFF_0000_0000));

		enum StackSize = 0x1000;
		VirtAddress userStack = VirtAddress(process.heap.Alloc(StackSize)) + StackSize;
		process.image.userStack = userStack;
		process.threadState.tls = TLS.Init(process, false);

		{
			ubyte length = 0;
			foreach (arg; tmpArgs)
				length += arg.length + 1;

			const ulong endOfArgs = length;
			length += ulong.sizeof * (tmpArgs.length + 1);

			VirtAddress elfArgs = process.heap.Alloc(length).VirtAddress;
			VirtAddress cur = elfArgs;
			char*[] entries = (elfArgs + endOfArgs).Ptr!(char*)[0 .. tmpArgs.length + 1];
			foreach (idx, arg; tmpArgs) {
				entries[idx] = cur.Ptr!char;
				cur.Ptr!char[0 .. arg.length] = arg[];
				cur.Ptr!ubyte[arg.length] = 0;
				cur += arg.length + 1;
			}
			entries[$ - 1] = null;

			process.image.arguments = cast(char*[])entries;
		}

		process.name = file.Name.dup;
		process.image.file = file;
		process.image.elf = this;

		foreach (arg; tmpArgs)
			arg.destroy;
		tmpArgs.destroy;

		switchToUserMode(header.entry.Int, userStack.Int);
	}

	ELF64ProgramHeader GetProgramHeader(size_t idx) {
		assert(idx < header.programHeaderCount);
		ELF64ProgramHeader programHdr;
		file.Read(&programHdr, header.programHeaderOffset + header.programHeaderEntrySize * idx);
		return programHdr;
	}

	ELF64SectionHeader GetSectionHeader(size_t idx) {
		assert(idx < header.sectionHeaderCount);
		ELF64SectionHeader sectionHdr;
		file.Read(&sectionHdr, header.sectionHeaderOffset + header.sectionHeaderEntrySize * idx);
		return sectionHdr;
	}

	ELF64Symbol GetSymbol(size_t idx) {
		assert(symtabIdx != ulong.max);
		ELF64SectionHeader symtab = GetSectionHeader(symtabIdx);
		ELF64Symbol symbol;
		file.Read(&symbol, symtab.offset + ELF64Symbol.sizeof * idx);
		return symbol;
	}

	/// Note that the output will only be valid until GetSectionName is called again
	char[] GetSectionName(uint nameIdx) {
		__gshared char[255] buf;
		if (!header.sectionHeaderStringTableIndex)
			return cast(char[])"UNKNOWN";

		file.Read(buf, GetSectionHeader(header.sectionHeaderStringTableIndex).offset + nameIdx);

		return buf[0 .. strlen(buf)];
	}

	/// Note that the output will only be valid until GetSymbolName is called again
	char[] GetSymbolName(uint idx) {
		__gshared char[255] buf;
		if (!strtabIdx)
			return cast(char[])"UNKNOWN";

		file.Read(buf, GetSectionHeader(strtabIdx).offset + idx);

		return buf[0 .. strlen(buf)];
	}

	@property bool Valid() {
		return valid;
	}

	@property ELF64Header Header() {
		return header;
	}

private:
	FileNode file;
	bool valid;
	ELF64Header header;
	ulong strtabIdx = ulong.max;
	ulong symtabIdx = ulong.max;
}
