module arch.amd64.acpi;

import data.address;
import io.log : Log;

@safe align(1) struct RSDPv1 {
align(1):
	char[8] signature;
	ubyte checksum;
	char[6] oemID;
	ubyte revision;
	PhysAddress32 rsdtAddress;

	@property bool valid() @trusted {
		ubyte count;
		foreach (b; (cast(ubyte*)&this)[0 .. RSDPv1.sizeof])
			count += b;

		return !count;
	}
}

@safe align(1) struct RSDPv2 {
align(1):
	RSDPv1 base;
	alias base this;

	uint length;
	PhysAddress xsdtAddress;
	ubyte extendedChecksum;
	ubyte[3] reserved;

	@property bool valid() @trusted {
		ubyte count;
		foreach (b; (cast(ubyte*)&this)[0 .. RSDPv2.sizeof])
			count += b;

		return !count;
	}
}

@safe align(1) struct SDTHeader {
align(1):
	char[4] signature;
	uint length;
	ubyte revision;
	ubyte checksum;
	char[6] oemID;
	char[8] oemTableID;
	uint oemRevision;
	char[4] creatorID;
	uint creatorRevision;

	@property bool valid() @trusted {
		ubyte count;
		foreach (b; (cast(ubyte*)&this)[0 .. length])
			count += b;

		return !count;
	}

	void print() {
		Log.info("signature: ", signature[0 .. 4], ", length: ", length, ", revision: ", revision, ", checksum: ", checksum,
				", oemID: ", oemID[0 .. 6], ", oemTableID: ", oemTableID[0 .. 8], ", oemRevision: ", oemRevision,
				", creatorID: ", creatorID[0 .. 4], ", creatorRevision: ", creatorRevision);
	}
}

@safe struct RSDTv1 {
	SDTHeader base;
	alias base this;

	@property PhysAddress32[] otherSDT() @trusted {
		return (VirtAddress(&this) + RSDTv1.sizeof).ptr!PhysAddress32[0 .. (base.length - RSDTv1.sizeof) / 4];
	}
}

@safe struct RSDTv2 {
	SDTHeader base;
	alias base this;

	@property PhysAddress[] otherSDT() @trusted {
		return (VirtAddress(&this) + RSDTv2.sizeof).ptr!PhysAddress[0 .. (base.length - RSDTv2.sizeof) / 8];
	}
}

@safe static struct ACPI {
public static:
	void initOld(ubyte[] rsdpData) {
		RSDPv1* rsdp = &(cast(RSDPv1[])rsdpData)[0];
		assert(rsdp.revision == 0, "RSDP is not version 1.0!");

		Log.info("ACPI/RSDP OEM is: ", rsdp.oemID[0 .. 6]);

		RSDTv1* rsdt = rsdp.rsdtAddress.toX64.VirtAddress.ptr!RSDTv1;
		assert(rsdt.valid);
		rsdt.print();

		foreach (PhysAddress32 pSDT; rsdt.otherSDT) {
			SDTHeader* sdt = pSDT.toX64.toVirtual.ptr!SDTHeader;
			if (!sdt.valid)
				Log.error("SDT [", sdt, "] has an invalid checksum!");
			sdt.print();
		}
	}

	void initNew(ubyte[] rsdpData) {
		RSDPv2* rsdp = &(cast(RSDPv2[])rsdpData)[0];
		assert(rsdp.revision >= 2, "RSDP is not >= version 2.0!");

		Log.info("ACPI/RSDP OEM is: ", rsdp.oemID[0 .. 6]);

		RSDTv1* rsdt = rsdp.rsdtAddress.toX64.VirtAddress.ptr!RSDTv1;
		assert(rsdt.valid);
		rsdt.print();

		foreach (PhysAddress32 pSDT; rsdt.otherSDT) {
			SDTHeader* sdt = pSDT.toX64.toVirtual.ptr!SDTHeader;
			if (!sdt.valid)
				Log.error("SDT [", sdt, "] has an invalid checksum!");
			sdt.print();
		}
	}

private static:
}
