module Data.Multiboot;

import Data.Linker;
import IO.TextMode;
import IO.Log;
import Data.Address;

alias scr = GetScreen;

enum MultibootTagType {
	Align = 8,
	End = 0,
	CmdLine,
	BootLoaderName,
	Module,
	BasicMemInfo,
	BootDev,
	MemoryMap,
	VBE,
	FrameBuffer,
	ElfSections,
	APM,
	EFI32,
	EFI64,
	SMBIOS,
	ACPIOld,
	ACPINew,
	Network,
	EFIMemoryMap,
	EFIBS
}

enum MultibootFramebufferType {
	Indexed,
	RGB,
	EGAText
}

enum MultibootMemoryType {
	Available = 1,
	Reserved,
	ACPIReclaimable,
	NVS,
	BadRAM
}

struct MultibootColor {
align(1):
	ubyte Red;
	ubyte Green;
	ubyte Blue;
}

struct MultibootMemoryMap {
align(1):
	ulong Address;
	ulong Length;
	uint Type;
	private uint m_zero;
}

struct MultibootTag {
align(1):
	uint Type;
	uint Size;
}

struct MultibootTagString {
align(1):
	uint Type;
	uint Size;
	char String;
}

struct MultibootTagModule {
align(1):
	uint Type;
	uint Size;
	uint ModStart;
	uint ModEnd;
	char String;
}

struct MultibootTagBasicMemInfo {
align(1):
	uint Type;
	uint Size;
	uint Lower;
	uint Upper;
}

struct MultibootTagBootDev {
align(1):
	uint Type;
	uint Size;
	uint BiosDev;
	uint Slice;
	uint Part;
}

struct MultibootTagMemoryMap {
align(1):
	uint Type;
	uint Size;
	uint EntrySize;
	uint EntryVersion;
	MultibootMemoryMap Entry;
}

struct MultibootTagFramebufferCommon {
align(1):
	uint Type;
	uint Size;

	ulong Address;
	uint Pitch;
	uint Width;
	uint Height;
	ubyte Bpp;
	ubyte FramebufferType;
	private ushort m_reserved;
}

struct MultibootTagFramebuffer {
align(1):
	MultibootTagFramebufferCommon Common;

	union {
		struct {
			ushort PaletteNumColors;
			MultibootColor Palette;
		}

		struct {
			ubyte RedFieldPos;
			ubyte RedMaskSize;
			ubyte GreenFieldPos;
			ubyte GreenMaskSize;
			ubyte BlueFieldPos;
			ubyte BlueMaskSize;
		}
	}
}

struct Multiboot {
	private enum {
		HEADER_MAGIC = 0xE85250D6,
		BOOTLOADER_MAGIC = 0x36D76289
	}

	__gshared MultibootTagModule*[256] Modules;
	__gshared MultibootMemoryMap*[256] MemoryMap;
	__gshared int ModulesCount;
	__gshared int MemoryMapCount;
	__gshared ulong memorySize;

	static void ParseHeader(uint magic, ulong info) {
		if (magic != BOOTLOADER_MAGIC) {
			scr.Writeln("Error: Bad multiboot 2 magic: %d", magic);
			while (true) {
			}
		}

		if (info & 7) {
			scr.Writeln("Error: Unaligned MBI");
			while (true) {
			}
		}

		//log.Info("Size: ", cast(ulong*)info);
		MultibootTag* mbt = cast(MultibootTag*)(info + Linker.KernelStart + 8);
		for (; mbt.Type != MultibootTagType.End; mbt = cast(MultibootTag*)(cast(ulong)mbt + ((mbt.Size + 7UL) & ~7UL))) {
			switch (mbt.Type) {
			case MultibootTagType.CmdLine:
				auto tmp = cast(MultibootTagString*)mbt;
				char* str = &tmp.String;

				//log.Info("Name: CMDLine, Value: ", cast(string)str[0 .. tmp.Size - 9]);
				break;

			case MultibootTagType.BootLoaderName:
				auto tmp = cast(MultibootTagString*)mbt;
				char* str = &tmp.String;

				//log.Info("Name: BootLoaderName, Value: ", cast(string)str[0 .. tmp.Size - 9]);
				break;

			case MultibootTagType.Module:
				auto tmp = cast(MultibootTagModule*)mbt;

				char* str = &tmp.String;
				Modules[ModulesCount++] = tmp;

				log.Info("Name: Module, Start: ", tmp.ModStart, ", End: ", tmp.ModEnd, ", CMD: ", cast(string)str[0 .. tmp.Size - 17]);
				break;

			case MultibootTagType.BasicMemInfo:
				auto tmp = cast(MultibootTagBasicMemInfo*)mbt;

				//log.Info("Memory is: ", (tmp.Lower + tmp.Upper) / 1024, " MiB");
				//log.Info("Name: BasicMemInfo, Lower: ", tmp.Lower, ", Upper: ", tmp.Upper);
				memorySize = tmp.Lower + tmp.Upper;
				break;

			case MultibootTagType.BootDev:
				auto tmp = cast(MultibootTagBootDev*)mbt;
				//log.Info("Name: BootDev, Device: ", tmp.BiosDev, ", Slice: ", tmp.Slice, ", Part: ", tmp.Part);
				break;

			case MultibootTagType.MemoryMap:
				//log.Info("MemoryMap ---->");
				for (auto tmp = &(cast(MultibootTagMemoryMap*)mbt).Entry; cast(void*)tmp < (cast(void*)mbt + mbt.Size); tmp = cast(
						MultibootMemoryMap*)(cast(ulong)tmp + (cast(MultibootTagMemoryMap*)mbt).EntrySize)) {
					MemoryMap[MemoryMapCount++] = tmp;
					log.Info("BaseAddr: ", cast(void*)tmp.Address, ", Length: ", cast(void*)tmp.Length, ", Type: ", tmp.Type);
				}
				break;

			case MultibootTagType.VBE:
				break;

			case MultibootTagType.FrameBuffer:
				uint color;
				auto tmp = cast(MultibootTagFramebuffer*)mbt;

				switch (tmp.Common.FramebufferType) {
				case MultibootFramebufferType.Indexed:
					uint distance;
					uint bestDistance = 4 * 256 * 256;
					auto palette = &tmp.Palette;

					for (int i = 0; i < tmp.PaletteNumColors; i++) {
						distance = (0xFF - palette[i].Blue) * (0xFF - palette[i].Blue) + palette[i].Red * palette[i].Red
							+ palette[i].Green * palette[i].Green;

						if (distance < bestDistance) {
							color = i;
							bestDistance = distance;
						}
					}
					break;

				case MultibootFramebufferType.RGB:
					color = ((1 << tmp.BlueMaskSize) - 1) << tmp.BlueFieldPos;
					break;

				case MultibootFramebufferType.EGAText:
					color = '\\' | 0x0100;
					break;

				default:
					color = 0xFFFFFFFF;
					break;
				}

				break;

			case MultibootTagType.ElfSections:
				break;

			case MultibootTagType.APM:
				break;

			case MultibootTagType.EFI32:
				break;

			case MultibootTagType.EFI64:
				break;

			case MultibootTagType.SMBIOS:
				break;

			case MultibootTagType.ACPIOld:
				break;

			case MultibootTagType.ACPINew:
				break;

			case MultibootTagType.Network:
				break;

			case MultibootTagType.EFIMemoryMap:
				break;

			case MultibootTagType.EFIBS:
				break;

			default:
				scr.Writeln("Multiboot2 Error tag type");
				break;
			}
		}
	}

	static VirtAddress[2] GetModule(string name) {
		foreach (mod; Modules[0 .. ModulesCount]) {
			char* str = &mod.String;
			if (str[0 .. mod.Size - 17] == name)
				return [PhysAddress(mod.ModStart).Virtual, PhysAddress(mod.ModEnd).Virtual];
		}
		return [VirtAddress(), VirtAddress()];
	}
}
