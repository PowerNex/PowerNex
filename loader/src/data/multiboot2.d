module data.multiboot2;

import data.address;
import io.log : Log;

///
enum Multiboot2TagType : uint {
	end = 0, /// See Multiboot2TagEnd
	cmdLine, /// See Multiboot2TagCmdLine
	bootLoaderName, /// See Multiboot2TagBootLoaderName
	module_, /// See Multiboot2TagModule
	basicMemInfo, /// See Multiboot2TagBasicMeminfo
	bootDev, /// See Multiboot2TagBootdev
	mMap, /// See Multiboot2TagMMap
	vbe, /// See Multiboot2TagVBE
	framebuffer, /// See Multiboot2TagFramebuffer
	elfSections, /// See Multiboot2TagELFSections
	apm, /// See Multiboot2TagAPM
	efi32, /// See Multiboot2TagEfi32
	efi64, /// See Multiboot2TagEfi64
	smbios, /// See Multiboot2TagSmbios
	acpiOld, /// See Multiboot2TagOldACPI
	acpiNew, /// See Multiboot2TagNewACPI
	network, /// See Multiboot2TagNetwork
	efiMMap, /// See Multiboot2TagEfiMMap
	efiBootServices, /// See Multiboot2TagBootServices
	efi32ImageHandle, /// See Multiboot2TagEfi32ImageHandle
	efi64ImageHandle, /// See Multiboot2TagEfi64ImageHandle
	loadBaseAddr /// See Multiboot2TagLoadBaseAddr
}

///
@safe struct Multiboot2Color {
	ubyte red; ///
	ubyte green; ///
	ubyte blue; ///
}

///
enum Multiboot2MemoryType : uint {
	available = 1, ///
	reserved = 2, ///
	acpiReclaimable = 3, ///
	nvs = 4, ///
	badRam = 5, ///
}

///
@safe struct Multiboot2MMapEntry {
	PhysAddress addr; ///
	ulong len; ///
	Multiboot2MemoryType type; ///
	private uint zero = 0;
}

alias Multiboot2MemoryMap = Multiboot2MMapEntry; ///

@safe struct Multiboot2TagsHeader {
	uint totalSize;
	private uint reserved;
}

///
@safe struct Multiboot2TagBase {
	Multiboot2TagType type; ///
	uint size; ///
}

///
@safe struct Multiboot2TagEnd {
	Multiboot2TagBase base; ///
	alias base this; ///
}

///
@safe struct Multiboot2TagCmdLine {
	Multiboot2TagBase base; ///
	alias base this; ///

	private char _cmdLine;
	///
	@property char[] cmdLine() @trusted {
		import data.text : strlen;

		char* str = &_cmdLine;
		return str[0 .. str.strlen];
	}
}

///
@safe struct Multiboot2TagBootLoaderName {
	Multiboot2TagBase base; ///
	alias base this; ///

	private char _bootLoaderName;
	///
	@property char[] bootLoaderName() @trusted {
		import data.text : strlen;

		char* str = &_bootLoaderName;
		return str[0 .. str.strlen];
	}
}

///
@safe struct Multiboot2TagModule {
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 modStart; ///
	PhysAddress32 modEnd; ///
	private char _name;

	///
	@property char[] name() @trusted {
		import data.text : strlen;

		char* str = &_name;
		return str[0 .. str.strlen];
	}
}

///
@safe struct Multiboot2TagBasicMeminfo {
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 memLower; ///
	PhysAddress32 memUpper; ///
}

///
@safe struct Multiboot2TagBootdev {
	Multiboot2TagBase base; ///
	alias base this; ///

	uint biosdev; ///
	uint slice; ///
	uint part; ///
}

///
@safe struct Multiboot2TagMMap {
	Multiboot2TagBase base; ///
	alias base this; ///

	uint entrySize; ///
	uint entryVersion; ///
	private Multiboot2MMapEntry _entries;

	///
	@property Multiboot2MMapEntry[] entries() @trusted {
		Multiboot2MMapEntry* ent = &_entries;
		return ent[0 .. (base.size - Multiboot2TagMMap.sizeof + _entries.sizeof) / entrySize];
	}
}

///
@safe struct Multiboot2TagVBE {
	Multiboot2TagBase base; ///
	alias base this; ///

	ushort mode;
	ushort interfaceSeg;
	ushort interfaceOff;
	ushort interfaceLen;

	ubyte[512] controlInfo; ///
	ubyte[256] modeInfo; ///
}

///
enum Multiboot2FramebufferType : ubyte {
	indexed = 0, ///
	rgb = 1, ///
	egaText = 2 ///
}

///
@safe struct Multiboot2TagFramebuffer { ///
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress addr;
	uint pitch;
	uint width;
	uint height;
	ubyte bpp;
	Multiboot2FramebufferType type;
	private ushort reserved;

	private union ExtraData {
		private struct Indexed { // Multiboot2FramebufferType.indexed
			ushort paletteNumColors; ///
			private Multiboot2Color _palette;

			///
			@property Multiboot2Color[] palette() @trusted {
				Multiboot2Color* colors = &_palette;
				return colors[0 .. paletteNumColors];
			}
		}

		Indexed indexed;

		private struct RGB { // Multiboot2FramebufferType.rgb
			ubyte redFieldPosition; ///
			ubyte redMaskSize; ///
			ubyte greenFieldPosition; ///
			ubyte greenMaskSize; ///
			ubyte blueFieldPosition; ///
			ubyte blueMaskSize; ///
		}

		RGB rgb;
	}

	ExtraData extraData;
}

/// TODO: Move to elf.d
/// Note: Needs align(1) because of Multiboot2TagELFSections._sections
@safe align(1) struct Elf64_Shdr {
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
@safe struct Multiboot2TagELFSections {
	Multiboot2TagBase base; ///
	alias base this; ///

	uint num; ///
	uint entsize; ///
	uint shndx; ///
	private Elf64_Shdr _sections;

	///
	@property Elf64_Shdr[] sections() @trusted {
		Elf64_Shdr* ent = &_sections;
		return ent[0 .. num];
	}
}

///
@safe struct Multiboot2TagAPM {
	Multiboot2TagBase base; ///
	alias base this; ///

	ushort version_;
	ushort cseg; ///
	uint offset; ///
	ushort cseg16; ///
	ushort dseg; ///
	ushort flags; ///
	ushort csegLen; ///
	ushort cseg16Len; ///
	ushort dsegLen; ///
}

///
@safe struct Multiboot2TagEfi32 {
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 pointer; ///
}

///
@safe struct Multiboot2TagEfi64 {
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress pointer; ///
}

///
@safe struct Multiboot2TagSmbios {
	Multiboot2TagBase base; ///
	alias base this; ///

	ubyte major; ///
	ubyte minor; ///
	private ubyte[6] reserved;
	private ubyte _tables;

	///
	@property ubyte[] tables() @trusted {
		ubyte* tables = &_tables;
		return tables[0 .. (base.size - Multiboot2TagSmbios.sizeof + _tables.sizeof)];
	}
}

///
@safe struct Multiboot2TagOldACPI {
	Multiboot2TagBase base; ///
	alias base this; ///

	private ubyte _rsdp;

	///
	@property ubyte[] rsdp() @trusted {
		ubyte* rsdp = &_rsdp;
		return rsdp[0 .. (base.size - Multiboot2TagOldACPI.sizeof + _rsdp.sizeof)];
	}
}

///
@safe struct Multiboot2TagNewACPI {
	Multiboot2TagBase base; ///
	alias base this; ///

	private ubyte _rsdp;

	///
	@property ubyte[] rsdp() @trusted {
		ubyte* rsdp = &_rsdp;
		return rsdp[0 .. (base.size - Multiboot2TagNewACPI.sizeof + _rsdp.sizeof)];
	}
}

///
@safe struct Multiboot2TagNetwork {
	Multiboot2TagBase base; ///
	alias base this; ///

	private ubyte _dhcpack;

	///
	@property ubyte[] dhcpack() @trusted {
		ubyte* dhcpack = &_dhcpack;
		return dhcpack[0 .. (base.size - Multiboot2TagNetwork.sizeof + _dhcpack.sizeof)];
	}
}

///
@safe struct Multiboot2TagEfiMMap {
	Multiboot2TagBase base; ///
	alias base this; ///

	uint descrSize; ///
	uint descrVers; ///
	private ubyte _efiMMap;

	///
	@property ubyte[] efiMMap() @trusted {
		ubyte* efiMMap = &_efiMMap;
		return efiMMap[0 .. (base.size - Multiboot2TagEfiMMap.sizeof + _efiMMap.sizeof)];
	}
}

///
@safe struct Multiboot2TagBootServices {
	Multiboot2TagBase base; ///
	alias base this; ///
}

///
@safe struct Multiboot2TagEfi32ImageHandle {
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 pointer; ///
}

///
@safe struct Multiboot2TagEfi64ImageHandle {
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress pointer; ///
}

///
@safe struct Multiboot2TagLoadBaseAddr {
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 loadBaseAddr; ///
}

private extern extern (C) __gshared Multiboot2TagsHeader* multibootPointer;

@safe static struct Multiboot2 {
public static:
	///
	void init() @trusted {
		_tags = TagRange(multibootPointer.VirtAddress + Multiboot2TagsHeader.sizeof);
		parse();
	}

	//
	void parse() @trusted {
		foreach (tag; _tags) final switch (tag.type) with (Multiboot2TagType) {
		case end:
			//accept(cast(Multiboot2TagEnd*)tag);
			break;
		case cmdLine:
			accept(cast(Multiboot2TagCmdLine*)tag);
			break;
		case bootLoaderName:
			accept(cast(Multiboot2TagBootLoaderName*)tag);
			break;
		case module_:
			accept(cast(Multiboot2TagModule*)tag);
			break;
		case basicMemInfo:
			accept(cast(Multiboot2TagBasicMeminfo*)tag);
			break;
		case bootDev:
			accept(cast(Multiboot2TagBootdev*)tag);
			break;
		case mMap:
			accept(cast(Multiboot2TagMMap*)tag);
			break;
		case vbe:
			accept(cast(Multiboot2TagVBE*)tag);
			break;
		case framebuffer:
			accept(cast(Multiboot2TagFramebuffer*)tag);
			break;
		case elfSections:
			accept(cast(Multiboot2TagELFSections*)tag);
			break;
		case apm:
			accept(cast(Multiboot2TagAPM*)tag);
			break;
		case efi32:
			accept(cast(Multiboot2TagEfi32*)tag);
			break;
		case efi64:
			accept(cast(Multiboot2TagEfi64*)tag);
			break;
		case smbios:
			accept(cast(Multiboot2TagSmbios*)tag);
			break;
		case acpiOld:
			accept(cast(Multiboot2TagOldACPI*)tag);
			break;
		case acpiNew:
			accept(cast(Multiboot2TagNewACPI*)tag);
			break;
		case network:
			accept(cast(Multiboot2TagNetwork*)tag);
			break;
		case efiMMap:
			accept(cast(Multiboot2TagEfiMMap*)tag);
			break;
		case efiBootServices:
			accept(cast(Multiboot2TagBootServices*)tag);
			break;
		case efi32ImageHandle:
			accept(cast(Multiboot2TagEfi32ImageHandle*)tag);
			break;
		case efi64ImageHandle:
			accept(cast(Multiboot2TagEfi64ImageHandle*)tag);
			break;
		case loadBaseAddr:
			accept(cast(Multiboot2TagLoadBaseAddr*)tag);
			break;
		}
	}

	///
	void accept(Multiboot2TagEnd* tag) {
		Log.debug_("Multiboot2TagEnd");
	}

	///
	void accept(Multiboot2TagCmdLine* tag) {
		Log.debug_("Multiboot2TagCmdLine: cmdLine: ", tag.cmdLine);
	}

	///
	void accept(Multiboot2TagBootLoaderName* tag) {
		Log.debug_("Multiboot2TagBootLoaderName: bootLoaderName: ", tag.bootLoaderName);
	}

	///
	void accept(Multiboot2TagModule* tag) {
		Log.debug_("Multiboot2TagModule: start: ", tag.modStart, ", end: ", tag.modEnd, ", name: ", tag.name);
	}

	///
	void accept(Multiboot2TagBasicMeminfo* tag) {
		Log.debug_("Multiboot2TagBasicMeminfo: lower:", tag.memLower, ", upper: ", tag.memUpper);
	}

	///
	void accept(Multiboot2TagBootdev* tag) {
		Log.debug_("Multiboot2TagBootdev: biosdev:", tag.biosdev, ", slice: ", tag.slice, ", part: ", tag.part);
	}

	///
	void accept(Multiboot2TagMMap* tag) {
		Log.debug_("Multiboot2TagMMap: size: ", tag.entrySize, " version: ", tag.entryVersion, ", entries:");
		foreach (const ref Multiboot2MMapEntry entry; tag.entries)
			Log.debug_("\taddr: ", entry.addr, ", len: ", entry.len.VirtAddress, ", type: ", entry.type);
	}

	///
	void accept(Multiboot2TagVBE* tag) {
		Log.debug_("Multiboot2TagVBE: mode: ", tag.mode, ", interfaceSeq: ", tag.interfaceSeg, ", interfaceOff",
				tag.interfaceOff, ", interfaceLen", tag.interfaceLen, ", controlInfo: ", &tag.controlInfo[0], ", modeInfo: ", &tag.modeInfo[0]);
	}

	///
	void accept(Multiboot2TagFramebuffer* tag) {
		Log.debug_("Multiboot2TagFramebuffer: addr: ", tag.addr, ", pitch: ", tag.pitch, ", width: ", tag.width,
				", height: ", tag.height, ", bpp: ", tag.bpp, ", type: ", tag.type);

		if (tag.type == Multiboot2FramebufferType.indexed)
			Log.debug_("\tpaletteNumColors: ", tag.extraData.indexed.paletteNumColors, ", palette: ", tag.extraData.indexed.palette);
		else if (tag.type == Multiboot2FramebufferType.rgb)
			Log.debug_("\tredFieldPosition: ", tag.extraData.rgb.redFieldPosition, ", redMaskSize: ",
					tag.extraData.rgb.redMaskSize, ", greenFieldPosition: ", tag.extraData.rgb.greenFieldPosition,
					", greenMaskSize: ", tag.extraData.rgb.greenMaskSize, ", blueFieldPosition: ",
					tag.extraData.rgb.blueFieldPosition, ", blueMaskSize: ", tag.extraData.rgb.blueMaskSize);
	}

	///
	void accept(Multiboot2TagELFSections* tag) {
		Log.debug_("Multiboot2TagELFSections: num: ", tag.num, ", entsize: ", tag.entsize, ", shndx: ", tag.shndx, ", sections: ");

		char[] lookUpName(uint nameIdx) @trusted {
			import data.text : strlen;

			auto tmp = tag.sections[tag.shndx];
			char* name = (tmp.addr + nameIdx).ptr!char;
			return name[0 .. name.strlen];
		}

		VirtAddress end;
		const(Elf64_Shdr)* tdata, tbss;
		foreach (const ref Elf64_Shdr section; tag.sections) {
			Log.debug_("\tname: '", lookUpName(section.name), "'(idx: ", section.name, "), type: ", section.type,
					", flags: ", section.flags.VirtAddress, ", addr: ", section.addr, ", offset: ", section.offset, ", size: ",
					section.size.VirtAddress, ", link: ", section.link, ", info: ", section.info, ", addralign: ",
					section.addralign.VirtAddress, ", entsize: ", section.entsize.VirtAddress);

			if (end < section.addr + section.size)
				end = section.addr + section.size;

			if (lookUpName(section.name) == ".tdata")
				tdata = &section;
			else if (lookUpName(section.name) == ".tbss")
				tbss = &section;
		}

		{
			import memory.allocator : Allocator;

			Allocator.init(end.roundUp(0x1000));
		}
		{
			import data.tls : TLS;

			TLS.init(tdata.addr, tdata.size, tbss.addr, tbss.size);
		}
	}

	///
	void accept(Multiboot2TagAPM* tag) {
		Log.debug_("Multiboot2TagAPM: version: ", tag.version_, ", cseg: ", tag.cseg, ", offset: ", tag.offset,
				", cseg16: ", tag.cseg16, ", dseg: ", tag.dseg, ", flags: ", tag.flags, ", csegLen: ", tag.csegLen,
				", cseg16Len: ", tag.cseg16Len, ", dsegLen: ", tag.dsegLen);
	}

	///
	void accept(Multiboot2TagEfi32* tag) {
		Log.debug_("Multiboot2TagEfi32: pointer: ", tag.pointer);
	}

	///
	void accept(Multiboot2TagEfi64* tag) {
		Log.debug_("Multiboot2TagEfi64: pointer: ", tag.pointer);
	}

	///
	void accept(Multiboot2TagSmbios* tag) {
		Log.debug_("Multiboot2TagSmbios: major", tag.major, ", minor: ", tag.minor, ", tables: ", tag.tables);
	}

	///
	void accept(Multiboot2TagOldACPI* tag) {
		Log.debug_("Multiboot2TagOldACPI: rsdp: ", &tag.rsdp[0]);
	}

	///
	void accept(Multiboot2TagNewACPI* tag) {
		Log.debug_("Multiboot2TagNewACPI: rsdp: ", &tag.rsdp[0]);
	}

	///
	void accept(Multiboot2TagNetwork* tag) {
		Log.debug_("Multiboot2TagNetwork: dhcpack: ", tag.dhcpack);
	}

	///
	void accept(Multiboot2TagEfiMMap* tag) {
		Log.debug_("Multiboot2TagEfiMMap: descrSize: ", tag.descrSize, ", descrVers: ", tag.descrVers, ", efiMMap: ", tag.efiMMap);
	}

	///
	void accept(Multiboot2TagBootServices* tag) {
		Log.debug_("Multiboot2TagBootServices: ", tag);
	}

	///
	void accept(Multiboot2TagEfi32ImageHandle* tag) {
		Log.debug_("Multiboot2TagEfi32ImageHandle: pointer: ", tag.pointer);
	}

	///
	void accept(Multiboot2TagEfi64ImageHandle* tag) {
		Log.debug_("Multiboot2TagEfi64ImageHandle: pointer: ", tag.pointer);
	}

	///
	void accept(Multiboot2TagLoadBaseAddr* tag) {
		Log.debug_("Multiboot2TagLoadBaseAddr: loadBaseAddr: ", tag.loadBaseAddr);
	}

private static:
	@trusted struct TagRange {
		VirtAddress tagAddr;
		Multiboot2TagBase* tag;

		this(VirtAddress tagAddr) {
			this.tagAddr = tagAddr;
			tag = tagAddr.ptr!Multiboot2TagBase;
		}

		@property bool empty() {
			return tag.type == Multiboot2TagType.end;
		}

		@property Multiboot2TagBase* front() {
			return tag;
		}

		void popFront() {
			tagAddr = (tagAddr + tag.size + 0x7) & ~0x7; // 8-byte alignment
			tag = tagAddr.ptr!Multiboot2TagBase;
		}
	}

	__gshared TagRange _tags;
}
