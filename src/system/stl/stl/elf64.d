module stl.elf64;

import stl.address;

///
@safe struct ELF64Header {
	///
	@safe struct Ident {
		///
		enum ubyte[4] magicValue = [0x7F, 'E', 'L', 'F'];
		///
		enum Class : ubyte {
			none = 0,
			class32 = 1,
			class64 = 2
		}

		///
		enum Data : ubyte {
			none = 0,
			twoLittleEndian = 1,
			twoBigEndian = 2
		}

		///
		enum Version : ubyte {
			none = 0,
			current = 1,
		}

		///
		enum OSABI : ubyte {
			sysv = 0,
			none = sysv
		}

		ubyte[4] magic; ///
		Class class_; ///
		Data data; ///
		Version version_; ///
		OSABI osABI; ///
		ubyte abiVersion; ///
		private ubyte[7] pad;
	}

	static assert(Ident.sizeof == 16);

	///
	enum Type : ushort {
		none = 0,
		relocateable = 1,
		executable = 2,
		shared_ = 3,
		core = 4
	}

	///
	enum Machine : ushort {
		none = 0,
		i386 = 3,
		x86_64 = 62
	}

	alias Version = Ident.Version; ///

	Ident ident; ///
	Type type; ///
	Machine machine; ///
	Version version_; ///
	VirtAddress entry; ///
	ulong programHeaderOffset; ///
	ulong sectionHeaderOffset; ///
	uint flags; ///
	ushort elfHeaderSize; ///
	ushort programHeaderEntrySize; ///
	ushort programHeaderCount; ///
	ushort sectionHeaderEntrySize; ///
	ushort sectionHeaderCount; ///
	ushort sectionHeaderStringIndex; ///
}

/// Note: Needs align(1) because of Multiboot2TagELFSections._sections
@safe align(1) struct ELF64SectionHeader {
	uint name; ///
	uint type; ///
	ulong flags; ///
	VirtAddress addr; ///
	VirtAddress offset; ///
	ulong size; ///
	uint link; ///
	uint info; ///
	ulong addralign; ///
	ulong entsize; ///
}

///
@safe struct ELF64ProgramHeader {
	enum Type : uint {
		null_ = 0, ///
		load = 1, ///
		dynamic = 2, ///
		interp = 3, ///
		note = 4, ///
		shlib = 5, ///
		phdr = 6, ///
		tls = 7, ///

		gnuEhFrame = 0x6474e550, /// GCC .eh_frame_hdr segment
		gnuStack = 0x6474e551, /// Indicates stack executability
		gnuRelRO = 0x6474e552 /// Read-only after relocation
	}

	enum Flags : uint {
		none,
		x = 1 << 0, ///
		w = 1 << 1, ///
		r = 1 << 2, ///

		// For readability

		rw_ = r | w,
		r_x = r | x,
		rwx = r | w | x
	}

	Type type; ///
	Flags flags; ///
	ulong offset; ///
	VirtAddress vAddr; ///
	PhysAddress pAddr; ///
	ulong filesz; ///
	ulong memsz; ///
	ulong align_; ///
}

///
struct ELF64Symbol {
	uint name; ///
	ubyte info; ///
	ubyte other; ///
	ushort shndx; ///
	VirtAddress value; ///
	ulong size; ///
}

///
@safe struct ELF64 {
public:
	///
	this(VirtMemoryRange kernelModule) {
		_elfData = kernelModule;
		_header = _elfData.start.ptr!ELF64Header;

		_verify();
		if (!_isValid)
			return;

		_programHeaders = (_elfData.start + _header.programHeaderOffset).array!ELF64ProgramHeader(_header.programHeaderCount);
		_sectionHeaders = (_elfData.start + _header.sectionHeaderOffset).array!ELF64SectionHeader(_header.sectionHeaderCount);

		if (_header.sectionHeaderStringIndex)
			_sectionNameStringTable = &_sectionHeaders[_header.sectionHeaderStringIndex];

		//_printProgramHeaders();
		//_printSectionHeaders();
	}

	ELF64ProgramHeader getProgramHeader(ELF64ProgramHeader.Type type) {
		foreach (ELF64ProgramHeader ph; programHeaders)
			if (ph.type == type)
				return ph;
		return ELF64ProgramHeader();
	}

	const(char)[] lookUpSectionName(uint nameIdx) @trusted {
		import stl.text : strlen;

		if (!_sectionNameStringTable)
			return "{No string table!}";

		const(char)* name = (_elfData.start + _sectionNameStringTable.offset + nameIdx).ptr!(const(char));
		return name[0 .. name.strlen];
	}

	@property bool isValid() {
		return _isValid;
	}

	@property VirtMemoryRange elfData() {
		return _elfData;
	}

	@property ELF64Header* header() {
		return _header;
	}

	@property ELF64ProgramHeader[] programHeaders() {
		return _programHeaders;
	}

	@property ELF64SectionHeader[] sectionHeaders() {
		return _sectionHeaders;
	}

	@property ELF64SectionHeader* sectionNameStringTable() {
		return _sectionNameStringTable;
	}

private:
	bool _isValid;
	VirtMemoryRange _elfData;
	ELF64Header* _header;
	ELF64ProgramHeader[] _programHeaders;
	ELF64SectionHeader[] _sectionHeaders;
	ELF64SectionHeader* _sectionNameStringTable;

	void _verify() {
		import stl.io.log : Log;

		if (_header.ident.magic != ELF64Header.Ident.magicValue)
			Log.fatal("File is not an ELF");
		if (_header.ident.class_ != ELF64Header.Ident.Class.class64)
			Log.fatal("File is not an ELF64");
		if (_header.ident.data != ELF64Header.Ident.Data.twoLittleEndian)
			Log.fatal("File is not 2LSB");
		if (_header.ident.version_ != ELF64Header.Ident.Version.current)
			Log.fatal("Files ELFVersion isn't current");
		if (_header.ident.osABI != ELF64Header.Ident.OSABI.sysv && _header.ident.abiVersion == 0)
			Log.fatal("File is not a SysV version 0");
		if (_header.programHeaderEntrySize != ELF64ProgramHeader.sizeof)
			Log.fatal("_header.programHeaderEntrySize != ELF64ProgramHeader.sizeof: ", _header.programHeaderEntrySize,
					" != ", ELF64ProgramHeader.sizeof);
		if (_header.sectionHeaderEntrySize != ELF64SectionHeader.sizeof)
			Log.fatal("_header.sectionHeaderEntrySize != ELF64SectionHeader.sizeof: ", _header.sectionHeaderEntrySize,
					" != ", ELF64SectionHeader.sizeof);
		Log.info("File is valid!");
		_isValid = true;
	}

	void _printProgramHeaders() {
		import stl.io.log : Log;

		foreach (const ref ELF64ProgramHeader programHeader; _programHeaders)
			with (programHeader)
				// dfmt off
				Log.debug_("ELF64ProgramHeader:",
					"\n\ttype: ", type,
					"\n\tflags: ", flags,
					"\n\toffset: ", offset,
					"\n\tvAddr: ", vAddr,
					"\n\tpAddr: ", pAddr,
					"\n\tfilesz: ", filesz,
					"\n\tmemsz: ", memsz,
					"\n\talign: ", align_
				);
				// dfmt on
	}

	void _printSectionHeaders() {
		import stl.io.log : Log;

		foreach (const ref ELF64SectionHeader sectionHeader; _sectionHeaders)
			with (sectionHeader)
				// dfmt off
				Log.debug_("ELF64SectionHeader:",
					"\n\tname: '", lookUpSectionName(name), "' (", name, ")",
					"\n\ttype: ", type,
					"\n\tflags: ", flags,
					"\n\taddr: ", addr,
					"\n\toffset: ", offset,
					"\n\tsize: ", size,
					"\n\tlink: ", link,
					"\n\tinfo: ", info,
					"\n\taddralign: ", addralign,
					"\n\tentsize: ", entsize
				);
				// dfmt on
	}
}
