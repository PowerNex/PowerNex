/**
 * A module for extracting information from the Multiboot2 data structures.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module data.multiboot2;

import stl.address;
import stl.io.log : Log;
import stl.text : HexInt;
import stl.elf64 : ELF64SectionHeader;

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
align(1):
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
align(1):
	PhysAddress addr; ///
	ulong len; ///
	Multiboot2MemoryType type; ///
	private uint zero = 0;
}

alias Multiboot2MemoryMap = Multiboot2MMapEntry; ///

@safe align(1) struct Multiboot2TagsHeader {
align(1):
	uint totalSize;
	private uint reserved;
}

///
@safe align(1) struct Multiboot2TagBase {
align(1):
	Multiboot2TagType type; ///
	uint size; ///
}

///
@safe align(1) struct Multiboot2TagEnd {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///
}

///
@safe align(1) struct Multiboot2TagCmdLine {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	///
	@property char[] cmdLine() @trusted {
		import stl.text : strlen;

		char* str = (VirtAddress(&this) + Multiboot2TagCmdLine.sizeof).ptr!char;

		return str[0 .. str.strlen];
	}
}

///
@safe align(1) struct Multiboot2TagBootLoaderName {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	///
	@property char[] bootLoaderName() @trusted {
		import stl.text : strlen;

		char* str = (VirtAddress(&this) + Multiboot2TagBootLoaderName.sizeof).ptr!char;
		return str[0 .. str.strlen];
	}
}

///
@safe align(1) struct Multiboot2TagModule {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 modStart; ///
	PhysAddress32 modEnd; ///

	///
	@property char[] name() @trusted {
		import stl.text : strlen;

		char* str = (VirtAddress(&this) + Multiboot2TagModule.sizeof).ptr!char;
		return str[0 .. str.strlen];
	}
}

///
@safe align(1) struct Multiboot2TagBasicMeminfo {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 memLower; ///
	PhysAddress32 memUpper; ///
}

///
@safe align(1) struct Multiboot2TagBootdev {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	uint biosdev; ///
	uint slice; ///
	uint part; ///
}

///
@safe align(1) struct Multiboot2TagMMap {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	uint entrySize; ///
	uint entryVersion; ///

	///
	@property Multiboot2MMapEntry[] entries() @trusted {
		return (VirtAddress(&this) + Multiboot2TagMMap.sizeof).ptr!Multiboot2MMapEntry[0 .. (base.size - Multiboot2TagMMap.sizeof) / entrySize];
	}
}

///
@safe align(1) struct Multiboot2TagVBE {
align(1):
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
@safe align(1) struct Multiboot2TagFramebuffer {
align(1):
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
		private @safe struct Indexed { // Multiboot2FramebufferType.indexed
		align(1):
			ushort paletteNumColors; ///

			///
			@property Multiboot2Color[] palette() @trusted {
				return (VirtAddress(&paletteNumColors) + paletteNumColors.sizeof).ptr!Multiboot2Color[0 .. paletteNumColors];
			}
		}

		Indexed indexed;

		private struct RGB { // Multiboot2FramebufferType.rgb
		align(1):
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

///
@safe align(1) struct Multiboot2TagELFSections {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	uint num; ///
	uint entsize; ///
	uint shndx; ///

	///
	@property ELF64SectionHeader[] sections() @trusted {
		return (VirtAddress(&this) + Multiboot2TagELFSections.sizeof).ptr!ELF64SectionHeader[0 .. num];
	}
}

///
@safe align(1) struct Multiboot2TagAPM {
align(1):
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
@safe align(1) struct Multiboot2TagEfi32 {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 pointer; ///
}

///
@safe align(1) struct Multiboot2TagEfi64 {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress pointer; ///
}

///
@safe align(1) struct Multiboot2TagSmbios {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	ubyte major; ///
	ubyte minor; ///
	private ubyte[6] reserved;

	///
	@property ubyte[] tables() @trusted {
		return (VirtAddress(&this) + Multiboot2TagSmbios.sizeof).ptr!ubyte[0 .. base.size - Multiboot2TagSmbios.sizeof];
	}
}

///
@safe align(1) struct Multiboot2TagOldACPI {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	///
	@property ubyte[] rsdp() @trusted {
		return (VirtAddress(&this) + Multiboot2TagOldACPI.sizeof).ptr!ubyte[0 .. base.size - Multiboot2TagOldACPI.sizeof];
	}
}

///
@safe align(1) struct Multiboot2TagNewACPI {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	///
	@property ubyte[] rsdp() @trusted {
		return (VirtAddress(&this) + Multiboot2TagNewACPI.sizeof).ptr!ubyte[0 .. base.size - Multiboot2TagNewACPI.sizeof];
	}
}

///
@safe align(1) struct Multiboot2TagNetwork {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	///
	@property ubyte[] dhcpack() @trusted {
		return (VirtAddress(&this) + Multiboot2TagNetwork.sizeof).ptr!ubyte[0 .. base.size - Multiboot2TagNetwork.sizeof];
	}
}

///
@safe align(1) struct Multiboot2TagEfiMMap {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	uint descrSize; ///
	uint descrVers; ///

	///
	@property ubyte[] efiMMap() @trusted {
		return (VirtAddress(&this) + Multiboot2TagEfiMMap.sizeof).ptr!ubyte[0 .. base.size - Multiboot2TagEfiMMap.sizeof];
	}
}

///
@safe align(1) struct Multiboot2TagBootServices {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///
}

///
@safe align(1) struct Multiboot2TagEfi32ImageHandle {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 pointer; ///
}

///
@safe align(1) struct Multiboot2TagEfi64ImageHandle {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress pointer; ///
}

///
@safe align(1) struct Multiboot2TagLoadBaseAddr {
align(1):
	Multiboot2TagBase base; ///
	alias base this; ///

	PhysAddress32 loadBaseAddr; ///
}

private extern extern (C) __gshared Multiboot2TagsHeader* multibootPointer;

@safe static struct Multiboot2 {
public static:
	//
	void earlyParse() @trusted {
		import stl.vmm.frameallocator : FrameAllocator;

		_tags = TagRange(multibootPointer.VirtAddress + Multiboot2TagsHeader.sizeof);

		foreach (tag; _tags) switch (tag.type) with (Multiboot2TagType) {
		case module_:
			auto t = cast(Multiboot2TagModule*)tag;
			FrameAllocator.markRange(t.modStart.toX64, t.modEnd.toX64);
			break;
		case basicMemInfo:
			auto t = cast(Multiboot2TagBasicMeminfo*)tag;
			FrameAllocator.maxFrames = (t.memLower + t.memUpper /* KiB */ ) / 4 /* each page is 4KiB */ ;
			break;
		case mMap:
			auto t = cast(Multiboot2TagMMap*)tag;
			foreach (const ref Multiboot2MMapEntry entry; t.entries) {
				if (entry.type != Multiboot2MemoryType.available)
					FrameAllocator.markRange(entry.addr, entry.addr + entry.len);
			}
			break;
		case elfSections:
			auto t = cast(Multiboot2TagELFSections*)tag;

			char[] lookUpName(uint nameIdx) @trusted {
				import stl.text : strlen;

				auto tmp = t.sections[t.shndx];
				char* name = (tmp.addr + nameIdx).ptr!char;
				return name[0 .. name.strlen];
			}

			VirtAddress start = ulong.max;
			VirtAddress end;
			immutable ELF64SectionHeader empty;
			const(ELF64SectionHeader)* tdata = &empty, tbss = &empty, symtab, strtab;
			foreach (const ref ELF64SectionHeader section; t.sections) {
				if (start > section.addr)
					start = section.addr;

				if (end < section.addr + section.size)
					end = section.addr + section.size;

				if (lookUpName(section.name) == ".tdata")
					tdata = &section;
				else if (lookUpName(section.name) == ".tbss")
					tbss = &section;
				else if (lookUpName(section.name) == ".symtab")
					symtab = &section;
				else if (lookUpName(section.name) == ".strtab")
					strtab = &section;
			}
			() @trusted{
				import stl.elf64 : ELF64Symbol;

				ELF64Symbol[] symbols = symtab.addr.ptr!ELF64Symbol[0 .. symtab.size / ELF64Symbol.sizeof];
				char[] strings = strtab.addr.ptr!char[0 .. strtab.size];

				Log.setSymbolMap(symbols, strings);
			}();
			FrameAllocator.markRange(start.PhysAddress, end.roundUp(0x1000).PhysAddress); // Gotta love identity mapping
			{
				import data.tls : TLS;

				TLS.init(tdata.addr, tdata.size, tbss.addr, tbss.size);
			}

			break;
		default:
			break;
		}
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
		import powerd.api : getPowerDAPI, Module;

		Log.debug_("Multiboot2TagModule: start: ", tag.modStart, ", end: ", tag.modEnd, ", name: ", tag.name);

		char[] nameRef = tag.name;
		import stl.vmm.heap : Heap;

		char[] name;
		() @trusted{ name = cast(char[])Heap.allocate(nameRef.length); }();
		name[] = nameRef[];
		getPowerDAPI().modules.put(Module(name, PhysMemoryRange32(tag.modStart, tag.modEnd).toX64));
	}

	///
	void accept(Multiboot2TagBasicMeminfo* tag) {
		import powerd.api : getPowerDAPI;

		Log.debug_("Multiboot2TagBasicMeminfo: lower:", tag.memLower, ", upper: ", tag.memUpper);

		getPowerDAPI.ramAmount = (tag.memLower + tag.memUpper /* KiB */ ) / 4 /* each page is 4KiB */ ;
	}

	///
	void accept(Multiboot2TagBootdev* tag) {
		Log.debug_("Multiboot2TagBootdev: biosdev:", tag.biosdev, ", slice: ", tag.slice, ", part: ", tag.part);
	}

	///
	void accept(Multiboot2TagMMap* tag) {
		import powerd.api : getPowerDAPI, MemoryMap;
		import stl.vmm.frameallocator : FrameAllocator;

		Log.debug_("Multiboot2TagMMap: size: ", tag.entrySize, " version: ", tag.entryVersion, ", entries:");
		foreach (const ref Multiboot2MMapEntry entry; tag.entries) {
			Log.debug_("\taddr: ", entry.addr, ", len: ", entry.len.HexInt, ", type: ", entry.type);
			getPowerDAPI.memoryMaps.put(MemoryMap(PhysMemoryRange(entry.addr, entry.addr + entry.len), cast(MemoryMap.Type)entry.type));
		}
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
			import stl.text : strlen;

			auto tmp = tag.sections[tag.shndx];
			char* name = (tmp.addr + nameIdx).ptr!char;
			return name[0 .. name.strlen];
		}

		foreach (const ref ELF64SectionHeader section; tag.sections)
			Log.debug_("\tname: '", lookUpName(section.name), "'(idx: ", section.name, "), type: ", section.type,
					", flags: ", section.flags.HexInt, ", addr: ", section.addr, ", offset: ", section.offset, ", size: ",
					section.size.HexInt, ", link: ", section.link, ", info: ", section.info, ", addralign: ",
					section.addralign.HexInt, ", entsize: ", section.entsize.HexInt);
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
		() @trusted{ _rsdpOld = tag.rsdp; }();
	}

	///
	void accept(Multiboot2TagNewACPI* tag) {
		Log.debug_("Multiboot2TagNewACPI: rsdp: ", &tag.rsdp[0]);
		() @trusted{ _rsdpNew = tag.rsdp; }();
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

	///
	@property ubyte[] rsdpOld() @trusted {
		return _rsdpOld;
	}

	///
	@property ubyte[] rsdpNew() @trusted {
		return _rsdpNew;
	}

	///
	PhysMemoryRange getModule(string name) {
		import powerd.api : getPowerDAPI, Module;

		foreach (ref const Module m; getPowerDAPI.modules) {
			Log.info(name, " == ", m.name);
			if (m.name == name)
				return m.memory;
		}

		return PhysMemoryRange();
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

	__gshared ubyte[] _rsdpOld;
	__gshared ubyte[] _rsdpNew;
}
