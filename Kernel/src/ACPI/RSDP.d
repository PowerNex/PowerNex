module ACPI.RSDP;

import Data.Address;
import Data.TextBuffer : scr = GetBootTTY;
import IO.Port;

struct RSDPDescriptor {
align(1):
	char[8] Signature;
	ubyte Checksum;
	char[6] OEMID;
	ubyte Revision;
	PhysAddress32 RSDTAddress;
}

struct RSDPDescriptor20 {
align(1):
	RSDPDescriptor firstPart;

	uint Length;
	PhysAddress XSDTAddress;
	ubyte ExtendedChecksum;
	ubyte[3] reserved;
}

struct ACPISDTHeader {
align(1):
	char[4] Signature;
	uint Length;
	ubyte Revision;
	ubyte Checksum;
	char[6] OEMID;
	char[8] OEMTableID;
	uint OEMRevision;
	uint CreatorID;
	uint CreatorRevision;
}

struct RSDT {
	ACPISDTHeader h;
	PhysAddress32[] PointerToOtherSDT() {
		auto ptr = VirtAddress(&h) + h.sizeof;
		return ptr.Ptr!PhysAddress32[0 .. (h.Length - h.sizeof) / 4];
	}

	T* GetSDT(T)(char[4] sig) {
		foreach (PhysAddress32 addr; PointerToOtherSDT) {
			ACPISDTHeader* hdr = addr.Virtual.Ptr!ACPISDTHeader;
			if (hdr.Signature == sig)
				return cast(T*)hdr;
		}

		return null;
	}
}

struct FADT {
align(1):
	ACPISDTHeader h;
	uint FirmwareCtrl;
	uint Dsdt;

	ubyte Reserved;

	ubyte PreferredPowerManagementProfile;
	ushort SCI_Interrupt;
	uint SMI_CommandPort;
	ubyte AcpiEnable;
	ubyte AcpiDisable;
	ubyte S4BIOS_REQ;
	ubyte PSTATE_Control;
	uint PM1aEventBlock;
	uint PM1bEventBlock;
	uint PM1aControlBlock;
	uint PM1bControlBlock;
	uint PM2ControlBlock;
	uint PMTimerBlock;
	uint GPE0Block;
	uint GPE1Block;
	ubyte PM1EventLength;
	ubyte PM1ControlLength;
	ubyte PM2ControlLength;
	ubyte PMTimerLength;
	ubyte GPE0Length;
	ubyte GPE1Length;
	ubyte GPE1Base;
	ubyte CStateControl;
	ushort WorstC2Latency;
	ushort WorstC3Latency;
	ushort FlushSize;
	ushort FlushStride;
	ubyte DutyOffset;
	ubyte DutyWidth;
	ubyte DayAlarm;
	ubyte MonthAlarm;
	ubyte Century;

	ushort BootArchitectureFlags;

	ubyte Reserved2;
	uint Flags;

	GenericAddressStructure ResetReg;

	ubyte ResetValue;
	ubyte[2] ARMBootArch;
	ubyte MinorVersion;
}

struct GenericAddressStructure {
align(1):
	ubyte AddressSpace;
	ubyte BitWidth;
	ubyte BitOffset;
	ubyte AccessSize;
	ulong Address;
}

struct RSDP {
	void Init() {
		VirtAddress addr = getAddress();
		if (!addr.Int)
			return scr.Writeln("RSDP: Can't find!");

		RSDPDescriptor* rsdp = addr.Ptr!RSDPDescriptor;
		if (!checksum(rsdp))
			return scr.Writeln("RSDPDescriptor: Invalid checksum");

		rsdt = rsdp.RSDTAddress.Virtual.Ptr!RSDT;

		fadt = rsdt.GetSDT!FADT("FACP");
		if (!checksum(fadt, fadt.h.Length))
			return scr.Writeln("FADT: Invalid checksum");

		scr.Writeln("ACPI Version: ", cast(int)fadt.h.Revision, ".", cast(int)fadt.MinorVersion);

		bool shouldEnable = !(fadt.SMI_CommandPort == 0 && fadt.AcpiEnable == 0 && fadt.AcpiDisable == 0 && fadt.PM1aControlBlock & 0x1);

		if (shouldEnable) {
			Out!ubyte(cast(ushort)fadt.SMI_CommandPort, fadt.AcpiEnable);
			while ((In!ushort(cast(ushort)fadt.PM1aControlBlock) & 1) == 0) {
			}
		}

		ACPISDTHeader* dsdt = PhysAddress32(fadt.Dsdt).Virtual.Ptr!ACPISDTHeader;
		if (dsdt.Signature != "DSDT" || !checksum(dsdt, dsdt.Length))
			return scr.Writeln("DSDT: Invalid checksum");

		ACPISDTHeader* ssdt = rsdt.GetSDT!ACPISDTHeader("SSDT");

		if (!checksum(ssdt, ssdt.Length))
			return scr.Writeln("SSDT: Invalid checksum");

		ubyte* s5Addr = (VirtAddress(dsdt) + ACPISDTHeader.sizeof).Ptr!ubyte;
		size_t len = dsdt.Length - dsdt.sizeof;
		size_t i;

		for (i = 0; i < len; i++) {
			if (s5Addr[0 .. 4] == "_S5_") {
				scr.Writeln("FOUND IT!");
				break;
			}
			s5Addr++;
		}

		if (i == len)
			return scr.Writeln("DSDT: Can't find _S5_");

		scr.Writeln("_S5_ Bytes -2 to 4: ", cast(void*)s5Addr[-2], ", ", cast(void*)s5Addr[-1], ", ",
				cast(void*)s5Addr[0], ", ", cast(void*)s5Addr[1], ", ", cast(void*)s5Addr[2], ", ",
				cast(void*)s5Addr[3], ", ", cast(void*)s5Addr[4]);

		if (!((s5Addr[-1] == 0x08 || (s5Addr[-2] == 0x08 && s5Addr[-1] == '\\')) && s5Addr[4] == 0x12))
			return scr.Writeln("_S5_: Parse error");

		s5Addr += 5;
		s5Addr += ((*s5Addr & 0xC0) >> 6) + 2; // calculate PkgLength size

		if (*s5Addr == 0x0A)
			s5Addr++; // skip byteprefix
		slpTypA = cast(ushort)(*(s5Addr) << 10);
		s5Addr++;

		if (*s5Addr == 0x0A)
			s5Addr++; // skip byteprefix
		slpTypB = cast(ushort)(*(s5Addr) << 10);

		slpEn = 1 << 13;
		sciEn = 1;

		valid = true;
		scr.Writeln("#########RSDP VALID!########");
	}

	void Shutdown() {
		if (!slpTypA) {
			Out!ushort(0xB004, 0x0 | 0x2000);

			asm {
				mov RAX, 0x1000; // Because page zero is not mapped
				mov RBX, 0x1337;
				lidt [RAX]; // and this will cause a Page fault before it changes the IDT
				int RBX; // And triple fault :D
			}
			while (true) {
			}
		}

		Out!ushort(cast(ushort)fadt.PM1aControlBlock, slpTypA | slpEn);
		if (fadt.PM1bControlBlock != 0)
			Out!ushort(cast(ushort)fadt.PM1bControlBlock, slpTypB | slpEn);
	}

private:
	RSDT* rsdt;
	FADT* fadt;

	bool valid;
	ushort slpTypA;
	ushort slpTypB;
	ushort slpEn;
	ushort sciEn;

	VirtAddress getAddress() {
		VirtAddress ptr;
		for (ptr = VirtAddress(0xFFFF_FFFF_800E_0000); ptr < 0xFFFF_FFFF_800F_FFFF; ptr += 16)
			if (ptr.Ptr!char[0 .. 8] == "RSD PTR ")
				return ptr;

		return VirtAddress(null);
	}

	bool checksum(T)(T* obj, size_t size = T.sizeof) {
		ubyte* ptr = cast(ubyte*)obj;
		ubyte check;
		foreach (i; 0 .. size)
			check += *(ptr++);
		return check == 0;
	}

}

__gshared RSDP rsdp;
