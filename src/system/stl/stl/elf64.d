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
		tls = 7 ///
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
@safe struct ELFInstance {
	import powerd.api : PowerDAPI;

	size_t function(PowerDAPI* powerDAPI) @system main;
	size_t function() @system[] ctors;
}

///
@safe struct ELF64 {
public:
	///
	this(PhysMemoryRange kernelModule) {
		// I can do this due to 1-to-1 mapping, and the loader + modules sizes are less than 1GiB
		_elfDataPhys = kernelModule;
		_elfData = kernelModule.toVirtual;
		_header = _elfData.start.ptr!ELF64Header;

		_verify();

		_programHeaders = (_elfData.start + _header.programHeaderOffset).array!(ELF64ProgramHeader[])(_header.programHeaderCount);
		_sectionHeaders = (_elfData.start + _header.sectionHeaderOffset).array!(ELF64SectionHeader[])(_header.sectionHeaderCount);

		if (_header.sectionHeaderStringIndex)
			_sectionNameStringTable = &_sectionHeaders[_header.sectionHeaderStringIndex];

		// _printProgramHeaders();
		// _printSectionHeaders();
	}

	/*ELFInstance aquireInstance() {
		ELFInstance instance;
		instance.main = () @trusted{ return cast(typeof(instance.main))_header.entry.ptr; }();

		_mapping();

		instance.ctors = _getCtors();

		return instance;
	}*/

private:
	PhysMemoryRange _elfDataPhys;
	VirtMemoryRange _elfData;
	ELF64Header* _header;
	ELF64ProgramHeader[] _programHeaders;
	ELF64SectionHeader[] _sectionHeaders;
	ELF64SectionHeader* _sectionNameStringTable;

	void _verify() {
		import stl.io.log : Log;

		if (_header.ident.magic != ELF64Header.Ident.magicValue)
			Log.fatal("Kernel is not an ELF");
		if (_header.ident.class_ != ELF64Header.Ident.Class.class64)
			Log.fatal("Kernel is not an ELF64");
		if (_header.ident.data != ELF64Header.Ident.Data.twoLittleEndian)
			Log.fatal("Kernel is not 2LSB");
		if (_header.ident.version_ != ELF64Header.Ident.Version.current)
			Log.fatal("Kernels ELFVersion isn't current");
		if (_header.ident.osABI != ELF64Header.Ident.OSABI.sysv && _header.ident.abiVersion == 0)
			Log.fatal("Kernel is not a SysV version 0");
		if (_header.programHeaderEntrySize != ELF64ProgramHeader.sizeof)
			Log.fatal("_header.programHeaderEntrySize != ELF64ProgramHeader.sizeof: ", _header.programHeaderEntrySize,
					" != ", ELF64ProgramHeader.sizeof);
		if (_header.sectionHeaderEntrySize != ELF64SectionHeader.sizeof)
			Log.fatal("_header.sectionHeaderEntrySize != ELF64SectionHeader.sizeof: ", _header.sectionHeaderEntrySize,
					" != ", ELF64SectionHeader.sizeof);
		Log.info("Kernel is valid!");
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

	const(char)[] _lookUpSectionName(uint nameIdx) @trusted {
		import stl.text : strlen;

		if (!_sectionNameStringTable)
			return "{No string table!}";

		const(char)* name = (_elfData.start + _sectionNameStringTable.offset + nameIdx).ptr!(const(char));
		return name[0 .. name.strlen];
	}

	void _printSectionHeaders() {
		import stl.io.log : Log;

		foreach (const ref ELF64SectionHeader sectionHeader; _sectionHeaders)
			with (sectionHeader)
				// dfmt off
				Log.debug_("ELF64SectionHeader:",
					"\n\tname: '", _lookUpSectionName(name), "' (", name, ")",
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

	/*
	void _mapping() {
		import stl.io.log : Log;
		import stl.vmm.frameallocator : FrameAllocator;
		import arch.amd64.paging : Paging, PageFlags;

		foreach (ref ELF64ProgramHeader hdr; _programHeaders) {
			if (hdr.type != ELF64ProgramHeader.Type.load)
				continue;

			VirtAddress vAddr = hdr.vAddr;
			VirtAddress data = _elfData.start + hdr.offset;
			PhysAddress pData = _elfDataPhys.start + hdr.offset;

			Log.info("Mapping [", vAddr, " - ", vAddr + hdr.memsz, "] to [", pData, " - ", pData + hdr.memsz, "]");
			FrameAllocator.markRange(pData, pData + hdr.memsz);
			for (size_t offset; offset < hdr.memsz; offset += 0x1000) {
				import stl.number : min;

				VirtAddress addr = vAddr + offset;
				PhysAddress pAddr = pData + offset;

				// Map with writable
				if (!Paging.map(addr, PhysAddress(), PageFlags.present | PageFlags.writable, false))
					Log.fatal("Failed to map ", addr, "( to ", pAddr, ")");

				// Copying the data over, and zeroing the excess
				size_t dataLen = (offset > hdr.filesz) ? 0 : min(hdr.filesz - offset, 0x1000);
				size_t zeroLen = min(0x1000 - dataLen, hdr.memsz - offset);

				addr.memcpy(data + offset, dataLen);
				(addr + dataLen).memset(0, zeroLen);

				// Remapping with correct flags
				PageFlags flags;
				if (hdr.flags & ELF64ProgramHeader.Flags.r)
					flags |= PageFlags.present;
				if (hdr.flags & ELF64ProgramHeader.Flags.w)
					flags |= PageFlags.writable;
				if (hdr.flags & ELF64ProgramHeader.Flags.x)
					flags |= PageFlags.execute;

				if (!Paging.remap(addr, PhysAddress(), flags))
					Log.fatal("Failed to remap ", addr);
			}
		}
	}

	auto _getCtors() {
		foreach (ref ELF64SectionHeader section; _sectionHeaders)
			if (_lookUpSectionName(section.name) == ".ctors")
				return VirtMemoryRange(section.addr, section.addr + section.size).array!(size_t function() @system);
		return null;
	}*/
}
