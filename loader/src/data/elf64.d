module data.elf64;

import data.address;
import io.log : Log;

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

	enum Type : ushort {
		none = 0,
		relocateable = 1,
		executable = 2,
		shared_ = 3,
		core = 4
	}

	enum Machine : ushort {
		none = 0,
		i386 = 3,
		x86_64 = 62
	}

	alias Version = Ident.Version;

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
align(1):
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
@safe struct ELFInstance {
	import api : APIInfo;

	int function(int argc, char** argv /*APIInfo**/ ) main;
	VirtMemoryRange ctor;
}

///
@safe struct ELF64 {
public:
	///
	this(PhysMemoryRange kernelModule) {
		// I can do this due to 1-to-1 mapping, and the loader + modules sizes are less than 1GiB
		_elfData = kernelModule.toVirtual;
		_header = _elfData.start.ptr!ELF64Header;

		_verify();

		_programHeaders = (_elfData.start + _header.programHeaderOffset).array!(ELF64ProgramHeader[])(_header.programHeaderCount);
		_printProgramHeaders();
	}

	ELFInstance aquireInstance() {
		import memory.frameallocator : FrameAllocator;
		import arch.amd64.paging : Paging, PageFlags;

		ELFInstance instance;
		instance.main = () @trusted{ return cast(typeof(instance.main))_header.entry.ptr; }();

		foreach (ref ELF64ProgramHeader hdr; _programHeaders) {
			if (hdr.type != ELF64ProgramHeader.Type.load)
				continue;

			VirtAddress vAddr = hdr.vAddr;
			VirtAddress data = _elfData.start + hdr.offset;

			Log.info("Mapping [", vAddr, " - ", vAddr + hdr.memsz, "] to [", hdr.pAddr, " - ", hdr.pAddr + hdr.memsz, "]");
			FrameAllocator.markRange(hdr.pAddr, hdr.pAddr + hdr.memsz);
			for (size_t offset; offset < hdr.memsz; offset += 0x1000) {
				import data.number : max, min;

				VirtAddress addr = vAddr + offset;
				PhysAddress pAddr = hdr.pAddr + offset;

				// Map with writable
				if (!Paging.map(addr, pAddr, PageFlags.present | PageFlags.writable, false))
					Log.fatal("Failed to map ", addr, "( to ", pAddr, ")");

				// Copying the data over, and zeroing the excess
				size_t dataLen = min(0x1000, max(0, hdr.filesz - offset));
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

		return instance;
	}

private:
	VirtMemoryRange _elfData;
	ELF64Header* _header;
	ELF64ProgramHeader[] _programHeaders;
	void _verify() {
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
		Log.info("Kernel is valid!");
	}

	void _printProgramHeaders() {
		foreach (const ref ELF64ProgramHeader programHeader; _programHeaders)
			with (programHeader)
				Log.debug_("ELF64ProgramHeader:", "\n\ttype: ", type, "\n\tflags: ", flags, "\n\toffset: ", offset,
						"\n\tvAddr: ", vAddr, "\n\tpAddr: ", pAddr, "\n\tfilesz: ", filesz, "\n\tmemsz: ", memsz, "\n\talign: ", align_);
	}

	void _allocate() {

	}
}
