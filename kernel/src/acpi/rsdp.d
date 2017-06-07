module acpi.rsdp;

import data.address;
import data.textbuffer : scr = getBootTTY;
import io.port;

struct RSDPDescriptor {
align(1):
	char[8] signature;
	ubyte checksum;
	char[6] oemID;
	ubyte revision;
	PhysAddress32 rsdtAddress;
}

struct RSDPDescriptor20 {
align(1):
	RSDPDescriptor firstPart;

	uint length;
	PhysAddress xsdtAddress;
	ubyte extendedChecksum;
	ubyte[3] reserved;
}

struct ACPISDTHeader {
align(1):
	char[4] signature;
	uint length;
	ubyte revision;
	ubyte checksum;
	char[6] oemID;
	char[8] oemTableID;
	uint oemRevision;
	uint creatorID;
	uint creatorRevision;
}

struct RSDT {
	ACPISDTHeader h;
	alias h this;

	PhysAddress32[] pointerToOtherSDT() {
		auto ptr = VirtAddress(&h) + h.sizeof;
		return ptr.ptr!PhysAddress32[0 .. (h.length - h.sizeof) / 4];
	}

	T* getSDT(T)(char[4] sig) {
		import arch.paging : kernelHWPaging;
		import memory.vmm : VMPageFlags;

		auto vAddr = _acpiMapping;

		ACPISDTHeader* hdr;
		foreach (PhysAddress32 phys; pointerToOtherSDT) {
			if (!phys)
				continue;
			auto pAddr = phys.toX64 & ~0xFFF;

			kernelHWPaging.map(vAddr, pAddr, VMPageFlags.present | VMPageFlags.writable /* Is needed ? */ );

			hdr = (vAddr + (phys.num & 0xFFF)).ptr!ACPISDTHeader;
			if (hdr.signature != sig) {
				import io.log : log;

				scr.writeln("hdr.signature (", hdr.signature, ") != sig (", sig, ")");
				continue;
			}

			vAddr += 0x1000;
			pAddr += 0x1000;

			size_t pagesUsed = 1;
			while (vAddr < hdr.VirtAddress + hdr.length) {
				pagesUsed++;
				kernelHWPaging.map(vAddr, pAddr, VMPageFlags.present | VMPageFlags.writable /* Is needed ? */ );

				vAddr += 0x1000;
				pAddr += 0x1000;
			}

			_acpiMapping += 0x1000 * pagesUsed;

			return cast(T*)hdr;
		}

		if (hdr)
			kernelHWPaging.unmap(vAddr);
		return null;
	}
}

struct FADT {
align(1):
	ACPISDTHeader h;
	alias h this;

	uint firmwareCtrl;
	PhysAddress32 dsdt;

	ubyte reserved;

	ubyte preferredPowerManagementProfile;
	ushort sciInterrupt;
	uint smiCommandPort;
	ubyte acpiEnable;
	ubyte acpiDisable;
	ubyte s4biosREQ;
	ubyte pstateControl;
	uint pm1aEventBlock;
	uint pm1bEventBlock;
	uint pm1aControlBlock;
	uint pm1bControlBlock;
	uint pm2ControlBlock;
	uint pmTimerBlock;
	uint gpe0Block;
	uint gpe1Block;
	ubyte pm1EventLength;
	ubyte pm1ControlLength;
	ubyte pm2ControlLength;
	ubyte pmTimerLength;
	ubyte gpe0Length;
	ubyte gpe1Length;
	ubyte gpe1Base;
	ubyte cstateControl;
	ushort worstC2Latency;
	ushort worstC3Latency;
	ushort flushSize;
	ushort flushStride;
	ubyte dutyOffset;
	ubyte dutyWidth;
	ubyte dayAlarm;
	ubyte monthAlarm;
	ubyte century;

	ushort bootArchitectureFlags;

	ubyte reserved2;
	uint flags;

	GenericAddressStructure resetReg;

	ubyte resetValue;
	ubyte[2] armBootArch;
	ubyte minorVersion;
}

struct GenericAddressStructure {
align(1):
	ubyte addressSpace;
	ubyte bitWidth;
	ubyte bitOffset;
	ubyte accessSize;
	ulong address;
}

import arch.paging : _makeAddress;

private __gshared VirtAddress _acpiMapping = _makeAddress(510, 0, 1, 0);

private T* _mapSDT(T : ACPISDTHeader = ACPISDTHeader)(PhysAddress phys) {
	import arch.paging : kernelHWPaging;
	import memory.vmm : VMPageFlags;

	if (!phys)
		return null;

	auto vAddr = _acpiMapping;
	auto pAddr = phys & ~0xFFF;

	T* result = (vAddr + (phys.num & 0xFFF)).ptr!T;

	size_t pagesUsed;
	do {
		pagesUsed++;
		kernelHWPaging.map(vAddr, pAddr, VMPageFlags.present | VMPageFlags.writable /* Is needed ? */ );

		vAddr += 0x1000;
		pAddr += 0x1000;
	}
	while (vAddr < result.VirtAddress + result.length);

	_acpiMapping += 0x1000 * pagesUsed;

	return result;
}

struct RSDP {
	void init() {
		import io.log : log;
		import data.multiboot : Multiboot;

		if (auto _ = Multiboot.acpiRSDPV20)
			initV20(_);
		else if (auto _ = Multiboot.acpiRSDPV10)
			initV10(_);
		else {
			scr.writeln("RSDP missing!");
			log.fatal("RSDP missing!");
		}
	}

	void initV20(VirtAddress addr) {
		// TODO:
		assert(0);
	}

	void initV10(VirtAddress addr) {
		RSDPDescriptor* rsdp = addr.ptr!RSDPDescriptor;
		if (!rsdp || !_checksum(rsdp))
			return scr.writeln("RSDP: Invalid checksum");

		if (!rsdp.rsdtAddress)
			return scr.writeln("RSDT: invalid");

		rsdt = _mapSDT!RSDT(rsdp.rsdtAddress.toX64);
		if (!rsdt || !_checksum(rsdt, rsdt.h.length))
			return scr.writeln("RSDT: Invalid checksum");

		fadt = rsdt.getSDT!FADT("FACP");

		if (!fadt || !_checksum(fadt, fadt.h.length))
			return scr.writeln("FADT: Invalid checksum");

		scr.writeln("ACPI Version: ", cast(int)fadt.h.revision, ".", cast(int)fadt.minorVersion);

		bool shouldEnable = !(fadt.smiCommandPort == 0 && fadt.acpiEnable == 0 && fadt.acpiDisable == 0 && fadt.pm1aControlBlock & 0x1);

		if (shouldEnable) {
			outp!ubyte(cast(ushort)fadt.smiCommandPort, fadt.acpiEnable);
			while ((inp!ushort(cast(ushort)fadt.pm1aControlBlock) & 1) == 0) {
			}
		}

		ACPISDTHeader* dsdt = _mapSDT!ACPISDTHeader(fadt.dsdt.toX64);
		if (!dsdt || dsdt.signature != "DSDT" || !_checksum(dsdt, dsdt.length))
			return scr.writeln("DSDT: Invalid checksum");

		ubyte* s5Addr = (VirtAddress(dsdt) + ACPISDTHeader.sizeof).ptr!ubyte;
		size_t len = dsdt.length - dsdt.sizeof;
		size_t i;

		for (i = 0; i < len; i++) {
			if (s5Addr[0 .. 4] == "_S5_") {
				//scr.writeln("FOUND IT!");
				break;
			}
			s5Addr++;
		}

		if (i == len)
			return scr.writeln("DSDT: Can't find _S5_");

		/*scr.writeln("_S5_ Bytes -2 to 4: ", cast(void*)s5Addr[-2], ", ", cast(void*)s5Addr[-1], ", ",
				cast(void*)s5Addr[0], ", ", cast(void*)s5Addr[1], ", ", cast(void*)s5Addr[2], ", ", cast(void*)s5Addr[3],
				", ", cast(void*)s5Addr[4]);*/

		if (!((s5Addr[-1] == 0x08 || (s5Addr[-2] == 0x08 && s5Addr[-1] == '\\')) && s5Addr[4] == 0x12))
			return scr.writeln("_S5_: Parse error");

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
		//scr.writeln("#########RSDP VALID!########");
	}

	void shutdown() {
		if (!valid) {
			outp!ushort(0xB004, 0x0 | 0x2000);

			asm pure nothrow {
				mov RAX, 0x1000; // Because page zero is not mapped
				mov RBX, 0x1337;
				lidt [RAX]; // and this will cause a Page fault before it changes the IDT
				int RBX; // And triple fault :D
			}
			while (true) {
			}
		}

		outp!ushort(cast(ushort)fadt.pm1aControlBlock, slpTypA | slpEn);
		if (fadt.pm1bControlBlock != 0)
			outp!ushort(cast(ushort)fadt.pm1bControlBlock, slpTypB | slpEn);
	}

	@property RSDT* rsdtInstance() {
		return rsdt;
	}

	@property FADT* fadtInstance() {
		return fadt;
	}

private:
	RSDT* rsdt;
	FADT* fadt;

	bool valid;
	ushort slpTypA;
	ushort slpTypB;
	ushort slpEn;
	ushort sciEn;

	bool _checksum(T)(T* obj, size_t size = T.sizeof) {
		if (!obj)
			return false;
		ubyte* ptr = cast(ubyte*)obj;
		ubyte check;
		foreach (i; 0 .. size)
			check += *(ptr++);
		return check == 0;
	}

}

__gshared RSDP rsdp;
