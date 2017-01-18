module data.elf;

import data.bitfield;
import data.address;
import data.string_;
import fs;
import io.log;
import data.textbuffer : scr = getBootTTY;
import task.process;
import memory.heap;
import memory.allocator;
import memory.ref_;

struct ELF64Header {
	struct Identification {
		char[4] magic;

		enum Class : ubyte {
			none,
			_32,
			_64
		}

		Class class_;

		enum Data : ubyte {
			none,
			leastSignificantBit,
			mostSignificantBit
		}

		Data data;

		enum ELFVersion : ubyte {
			none,
			current
		}

		ELFVersion elfVersion;

		enum OSABI : ubyte {
			none,
			powerNex = 16
		}

		OSABI osABI;

		enum ABIVersion : ubyte {
			current = 0
		}

		ABIVersion abiVersion;

		private char[7] pad;
	}

	static assert(Identification.sizeof == 16);
	Identification identification;

	enum ObjectType : ushort {
		none,
		relocatable,
		executable,
		shared_,
		core
	}

	ObjectType type;

	enum Machine : ushort {
		none,
		i386 = 3,
		amd64 = 0x3E
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

	@property bool valid() {
		immutable char[4] elf64Magic = [0x7F, 'E', 'L', 'F'];
		return identification.magic == elf64Magic && programHeaderEntrySize == ELF64ProgramHeader.sizeof
			&& ELF64SectionHeader.sizeof == sectionHeaderEntrySize;
	}
}

struct ELF64ProgramHeader {
	enum Type : uint {
		null_,
		load,
		dynamic,
		interpreter,
		note,
		shlib, // Not use, Not allowed
		programHeader,
		threadLocalStorage,

		gnuEHFrameHeader = 0x6474E550,
		gnuStack = 0x6474E551,
	}

	Type type;

	enum Flags : uint {
		none,
		x = 1 << 0,
		w = 1 << 1,
		r = 1 << 2
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
		null_,
		programBits,
		symbolTable,
		stringTable,
		relocationEntries,
		symbolHashTable,
		dynamicLinking,
		note,
		noBits,
		relocationOffsets,
		shlib, // Not used, not allowed
		dynamicLinkingSymbols,
		constructorArray = 14,
		destructorArray,
		preConstructorArray,
		gnuHashTable = 0x6FFFFFF6,
		gnuVersionNeeds = 0x6FFFFFFE,
		gnuVersionSymbolTable = 0x6FFFFFFF,
	}

	Type type;

	enum Flags : ulong {
		null_,
		write = 1 << 0,
		allocate = 1 << 1,
		executableInstructions = 1 << 2,
		merge = 1 << 4,
		strings = 1 << 5,
		infoLink = 1 << 6,
		linkOrder = 1 << 7,
		group = 1 << 9,
		threadLocalData = 1 << 10,
		compressed = 1 << 11,

		allocateWrite = allocate | write,
		executableInstructionsAllocate = executableInstructions | allocate,
		stringsMerge = strings | merge,
		infoLinkAllocate = infoLink | allocate,
		threadLocalDataAllocateWrite = threadLocalData | allocate | write
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
			noType,
			object,
			function_,
			section,
			file,
			common,
			tls
		}

		enum InfoBinding : ubyte {
			local,
			global,
			weak
		}

		private ubyte data;
		@property InfoType type() {
			return cast(InfoType)(data & 0xF);
		}

		@property InfoType type(InfoType type) {
			data = data & 0xF0 | type & 0xF;
			return type;
		}

		@property InfoBinding binding() {
			return cast(InfoBinding)((data & 0xF0 >> 4) & 0x2);
		}

		@property InfoBinding binding(InfoBinding binding) {
			data = (binding << 4) & 0xF0 | data & 0xF;
			return binding;
		}
	}

	Info info;
	enum Other : ubyte {
		default_,
		internal,
		hidden,
		protected_
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
		null_,
		needed,
		pltRelocationEntries,
		pltgot,
		hashTable,
		stringTable,
		symbolTable,
		relocationAddendTable,
		relocationAddendTableSize,
		relocationAddendTableEntrySize,
		stringTableSize,
		symbolTableEntrySize,
		init,
		fini,
		sOName,
		rPath,
		symbolic,
		relocationTable,
		relocationTableSize,
		relocationTableEntrySize,
		pLTRel,
		debug_,
		textRel,
		jumpRel,
		bindNow,
		runPath
	}

	Tag tag;
	VirtAddress valueOrAddress;
}

class ELF {
public:
	this(Ref!VNode file) {
		this._file = file;

		if (_file.size <= ELF64Header.sizeof)
			return;

		if (_file.open(nc, FileDescriptorMode.read))
			return;

		read(_file, nc, _header);
		_valid = _header.valid;

		foreach (idx; 0 .. _header.sectionHeaderCount) {
			ELF64SectionHeader sectionHdr = getSectionHeader(idx);
			if (sectionHdr.type == ELF64SectionHeader.type.symbolTable)
				_symtabIdx = idx;
			else if (sectionHdr.type == ELF64SectionHeader.type.stringTable)
				_strtabIdx = idx;
		}
	}

	void mapAndRun(string[] args) {
		import memory.paging;
		import task.scheduler;

		Scheduler scheduler = getScheduler;
		Process* process = scheduler.currentProcess;
		Paging paging = process.threadState.paging;

		string[] tmpArgs;
		tmpArgs.length = args.length;
		foreach (idx, arg; args)
			tmpArgs[idx] = arg.dup;

		if (process.heap && !(--process.heap.refCounter))
			process.heap.destroy;

		paging.removeUserspace(true);

		VirtAddress startHeap;

		foreach (idx; 0 .. header.programHeaderCount) {
			ELF64ProgramHeader program = getProgramHeader(idx);
			if (program.type == ELF64ProgramHeader.type.load) {

				MapMode mode = MapMode.user;
				if (!(program.flags & ELF64ProgramHeader.Flags.x))
					mode |= MapMode.noExecute;
				if (program.flags & ELF64ProgramHeader.Flags.w)
					mode |= MapMode.writable;
				// Page will always be readable

				VirtAddress start = program.virtAddress & ~0xFFF;
				VirtAddress end = program.virtAddress + program.memorySize;
				VirtAddress cur = start;
				while (cur < end) {
					paging.mapFreeMemory(cur, MapMode.defaultKernel);
					cur += 0x1000;
				}

				log.debug_("Start: ", start, " End: ", end, " cur: ", cur, " Mode: R", (mode & MapMode.writable) ? "W" : "",
						(mode & MapMode.noExecute) ? "" : "X", (mode & MapMode.user) ? "-User" : "");

				memset(start.ptr, 0, (program.virtAddress - start).num);
				cur = (program.virtAddress + program.fileSize);
				memset(cur.ptr, 0, (end - cur).num);
				nc.offset = program.offset.num; //XXX: Add seek to VNode
				_file.read(nc, program.virtAddress.ptr!ubyte[0 .. program.fileSize]);

				cur = start;
				while (cur < end) {
					auto page = paging.getPage(cur);
					page.mode = mode;
					paging.flushPage(cur);
					cur += 0x1000;
				}

				if (end > startHeap)
					startHeap = end;
			} else if (program.type == ELF64ProgramHeader.Type.threadLocalStorage)
				process.image.defaultTLS = program.virtAddress.ptr!ubyte[0 .. program.memorySize];
		}

		// Setup stack, setup heap

		asm {
			cli;
		}

		startHeap = (startHeap.num + 0xFFF) & ~0xFFF;

		process.heap = new Heap(process.threadState.paging, MapMode.defaultUser, startHeap, VirtAddress(0xFFFF_FFFF_0000_0000));

		enum stackSize = 0x1000;
		VirtAddress userStack = VirtAddress(process.heap.alloc(stackSize)) + stackSize;
		process.image.userStack = userStack;
		process.threadState.tls = TLS.init(process, false);

		{
			ubyte length = 0;
			foreach (arg; tmpArgs)
				length += arg.length + 1;

			const ulong endOfArgs = length;
			length += ulong.sizeof * (tmpArgs.length + 1);

			VirtAddress elfArgs = process.heap.alloc(length).VirtAddress;
			VirtAddress cur = elfArgs;
			char*[] entries = (elfArgs + endOfArgs).ptr!(char*)[0 .. tmpArgs.length + 1];
			foreach (idx, arg; tmpArgs) {
				entries[idx] = cur.ptr!char;
				cur.ptr!char[0 .. arg.length] = arg[];
				cur.ptr!ubyte[arg.length] = 0;
				cur += arg.length + 1;
			}
			entries[$ - 1] = null;

			process.image.arguments = cast(char*[])entries;
		}

		process.name = _file.name.dup;
		process.image.file = _file;
		process.image.elf = this;

		foreach (arg; tmpArgs)
			arg.destroy;
		tmpArgs.destroy;

		switchToUserMode(header.entry.num, userStack.num);
	}

	ELF64ProgramHeader getProgramHeader(size_t idx) {
		assert(idx < header.programHeaderCount);
		ELF64ProgramHeader programHdr;
		nc.offset = header.programHeaderOffset + header.programHeaderEntrySize * idx;
		read(_file, nc, programHdr);
		return programHdr;
	}

	ELF64SectionHeader getSectionHeader(size_t idx) {
		assert(idx < header.sectionHeaderCount);
		ELF64SectionHeader sectionHdr;
		nc.offset = header.sectionHeaderOffset + header.sectionHeaderEntrySize * idx;
		read(_file, nc, sectionHdr);
		return sectionHdr;
	}

	ELF64Symbol getSymbol(size_t idx) {
		assert(_symtabIdx != ulong.max);
		ELF64SectionHeader symtab = getSectionHeader(_symtabIdx);
		ELF64Symbol symbol;
		nc.offset = symtab.offset + ELF64Symbol.sizeof * idx;
		read(_file, nc, symbol);
		return symbol;
	}

	/// Note that the output will only be valid until getSectionName is called again
	char[] getSectionName(uint nameIdx) {
		__gshared char[255] buf;
		if (!header.sectionHeaderStringTableIndex)
			return cast(char[])"UNKNOWN";

		nc.offset = getSectionHeader(header.sectionHeaderStringTableIndex).offset + nameIdx;
		_file.read(nc, cast(ubyte[])buf);

		return buf[0 .. strlen(buf)];
	}

	/// Note that the output will only be valid until getSymbolName is called again
	char[] getSymbolName(uint idx) {
		__gshared char[255] buf;
		if (!_strtabIdx)
			return cast(char[])"UNKNOWN";
		nc.offset = getSectionHeader(_strtabIdx).offset + idx;
		_file.read(nc, cast(ubyte[])buf);

		return buf[0 .. strlen(buf)];
	}

	@property bool valid() {
		return _valid;
	}

	@property ELF64Header header() {
		return _header;
	}

private:
	Ref!VNode _file;
	NodeContext nc;
	bool _valid;
	ELF64Header _header;
	ulong _strtabIdx = ulong.max;
	ulong _symtabIdx = ulong.max;
}
