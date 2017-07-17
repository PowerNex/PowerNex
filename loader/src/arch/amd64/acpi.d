module arch.amd64.acpi;

import data.address;
import io.log : Log;

///
@safe align(1) struct RSDPv1 {
align(1):
	char[8] signature; ///
	ubyte checksum; ///
	char[6] oemID; ///
	ubyte revision; ///
	PhysAddress32 rsdtAddress; ///

	///
	@property bool valid() @trusted {
		ubyte count;
		foreach (b; (cast(ubyte*)&this)[0 .. RSDPv1.sizeof])
			count += b;

		return !count;
	}
}

///
@safe align(1) struct RSDPv2 {
align(1):
	RSDPv1 base; ///
	alias base this;

	uint length; ///
	PhysAddress xsdtAddress; ///
	ubyte extendedChecksum; ///
	ubyte[3] reserved; ///

	///
	@property bool valid() @trusted {
		ubyte count;
		foreach (b; (cast(ubyte*)&this)[0 .. RSDPv2.sizeof])
			count += b;

		return !count;
	}
}

///
@safe align(1) struct SDTHeader {
align(1):
	char[4] signature; ///
	uint length; ///
	ubyte revision; ///
	ubyte checksum; ///
	char[6] oemID; ///
	char[8] oemTableID; ///
	uint oemRevision; ///
	char[4] creatorID; ///
	uint creatorRevision; ///

	///
	@property bool valid() @trusted {
		ubyte count;
		foreach (b; (cast(ubyte*)&this)[0 .. length])
			count += b;

		return !count;
	}

	///
	void print() {
		Log.info("signature: ", signature[0 .. 4], ", length: ", length, ", revision: ", revision, ", checksum: ", checksum,
				", oemID: ", oemID[0 .. 6], ", oemTableID: ", oemTableID[0 .. 8], ", oemRevision: ", oemRevision,
				", creatorID: ", creatorID[0 .. 4], ", creatorRevision: ", creatorRevision);
	}
}

///
@safe struct RSDTv1 {
	SDTHeader base; ///
	alias base this;

	///
	@property PhysAddress32[] otherSDT() @trusted {
		return (VirtAddress(&this) + RSDTv1.sizeof).ptr!PhysAddress32[0 .. (base.length - RSDTv1.sizeof) / 4];
	}
}

///
@safe struct RSDTv2 {
	SDTHeader base; ///
	alias base this;

	///
	@property PhysAddress[] otherSDT() @trusted {
		return (VirtAddress(&this) + RSDTv2.sizeof).ptr!PhysAddress[0 .. (base.length - RSDTv2.sizeof) / 8];
	}
}

///
@safe struct DSDT {
	SDTHeader base; ///
	alias base this;

	///
	@property ubyte[] amlData() @trusted {
		return (VirtAddress(&this) + DSDT.sizeof).ptr!ubyte[0 .. base.length - DSDT.sizeof];
	}
}

///
@safe struct PM1ControlBlock {
	import data.bitfield : bitfield;

	private ushort data;
	mixin(bitfield!(data, "sciEnable", 1));
}

static assert(PM1ControlBlock.sizeof == ushort.sizeof);

///
@safe struct FADTv1 {
align(1):
	///
	enum InterruptModel : ubyte {
		dualPIC = 0, ///
		multipleAPIC = 1 ///
	}

	SDTHeader base; ///
	alias base this;

	PhysAddress32 firmwareCtrl; ///
	PhysAddress32 dsdt; ///

	InterruptModel interruptModel; ///

	private ubyte reserved;
	ushort sciInterrupt; ///
	uint smiCommandPort; ///
	ubyte acpiEnable; ///
	ubyte acpiDisable; ///
	ubyte s4biosReq; ///
	ubyte pstateControl; ///
	uint pm1aEventBlock; ///
	uint pm1bEventBlock; ///
	uint pm1aControlBlock; ///
	uint pm1bControlBlock; ///
	uint pm2ControlBlock; ///
	uint pmTimerBlock; ///
	uint gpe0Block; ///
	uint gpe1Block; ///
	ubyte pm1EventLength; ///
	ubyte pm1ControlLength; ///
	ubyte pm2ControlLength; ///
	ubyte pmTimerLength; ///
	ubyte gpe0Length; ///
	ubyte gpe1Length; ///
	ubyte gpe1Base; ///
	private ubyte reserved2;
	ushort worstC2Latency; ///
	ushort worstC3Latency; ///
	ushort flushSize; ///
	ushort flushStride; ///
	ubyte dutyOffset; ///
	ubyte dutyWidth; ///
	ubyte dayAlarm; ///
	ubyte monthAlarm; ///
	ubyte century; ///

	private ubyte[3] reserved3;
	uint flags; ///
}

///
@safe struct FADTv2 {
	///
	@safe align(1) struct GenericAddressStructure {
	align(1):
		///
		enum AddressSpace : ubyte {
			systemMemory = 0, ///
			systemIO = 1, ///
			pciConfigurationSpace = 2, ///
			embeddedController = 3, ///
			smBus = 4, ///
			//reserved = 5 to 0x7E,
			functionalFixedHardware = 0x7F, ///
			//reserved = 0x80 to 0xBF,
			oemDefined_start = 0xC0, ///
			oemDefined_end = 0xFF ///
		}

		///
		enum AccessSize : ubyte {
			undefined = 0, ///
			byteAccess = 1, ///
			shortAccess = 2, ///
			intAccess = 3, ///
			longAccess = 4 ///
		}

		AddressSpace addressSpace; ///
		ubyte bitWidth; ///
		ubyte bitOffset; ///
		AccessSize accessSize; ///
		PhysAddress address; ///
	}

	///
	enum PreferredPowerManagementProfile : ubyte {
		unspecified = 0, ///
		desktop = 1, ///
		mobile = 2, ///
		workstation = 3, ///
		enterpriseServer = 4, ///
		sohoServer = 5, ///
		aplliancePC = 6, ///
		performanceServer = 7 ///
	}

	///
	enum InterruptModel : ubyte {
		dualPIC = 0, ///
		multipleAPIC = 1 ///
	}

align(1):

	SDTHeader base; ///
	alias base this;

	PhysAddress32 firmwareCtrl; ///
	PhysAddress32 dsdt; ///

	private ubyte reserved;

	PreferredPowerManagementProfile preferredPowerManagementProfile; ///
	ushort sciInterrupt; ///
	uint smiCommandPort; ///
	ubyte acpiEnable; ///
	ubyte acpiDisable; ///
	ubyte s4biosReq; ///
	ubyte pstateControl; ///
	deprecated uint pm1aEventBlock; ///
	deprecated uint pm1bEventBlock; ///
	deprecated uint pm1aControlBlock; ///
	deprecated uint pm1bControlBlock; ///
	deprecated uint pm2ControlBlock; ///
	deprecated uint pmTimerBlock; ///
	deprecated uint gpe0Block; ///
	deprecated uint gpe1Block; ///
	ubyte pm1EventLength; ///
	ubyte pm1ControlLength; ///
	ubyte pm2ControlLength; ///
	ubyte pmTimerLength; ///
	ubyte gpe0Length; ///
	ubyte gpe1Length; ///
	ubyte gpe1Base; ///
	ubyte cstateControl; ///
	ushort worstC2Latency; ///
	ushort worstC3Latency; ///
	ushort flushSize; ///
	ushort flushStride; ///
	ubyte dutyOffset; ///
	ubyte dutyWidth; ///
	ubyte dayAlarm; ///
	ubyte monthAlarm; ///
	ubyte century; ///

	ushort bootArchitectureFlags; ///

	private ubyte reserved2;
	uint flags; /// TODO: Add enum to represent flags

	GenericAddressStructure resetReg; ///

	ubyte resetValue; ///
	private ubyte[3] reserved3;

	PhysAddress xFirmwareControl; ///
	PhysAddress xDSDT; ///

	GenericAddressStructure xPM1aEventBlock; ///
	GenericAddressStructure xPM1bEventBlock; ///
	GenericAddressStructure xPM1aControlBlock; ///
	GenericAddressStructure xPM1bControlBlock; ///
	GenericAddressStructure xPM2ControlBlock; ///
	GenericAddressStructure xPMTimerBlock; ///
	GenericAddressStructure xGPE0Block; ///
	GenericAddressStructure xGPE1Block; ///
}

///
@safe struct MADT {
	///
	align(1) struct APICBase {
		///
		enum Type : ubyte {
			processorLocalAPIC = 0, ///
			ioAPIC = 1, ///
			interruptSourceOverride = 2, ///
			nmi = 3, ///
			localAPICNMI = 4, ///
			localAPICAddressOverride = 5, ///
			ioSAPIC = 6, ///
			localSAPIC = 7, ///
			platformInterruptSources = 8, ///
			processorLocalX2APIC = 9, ///
			localX2APICNMI = 0xA, ///
			gic = 0xB, ///
			gicd = 0xC ///
		}

		Type type; ///
		ubyte size; ///
	}

	///
	struct LAPIC {
		///
		enum Flags : uint {
			disabled = 0, ///
			enabled = 1 ///
		}

	align(1):
		APICBase base; ///
		alias base this;

		ubyte acpiID; ///
		ubyte apicID; ///
		Flags flags; /// 1 = Processor enabled
	}

	///
	struct X2LAPIC {
		///
		enum Flags : uint {
			disabled = 0, ///
			enabled = 1 ///
		}

	align(1):
		APICBase base; ///
		alias base this;

		private ushort reserved;
		uint x2apicID; ///
		Flags flags; ///
		uint acpiID; ///
	}

	///
	struct IOAPIC {
		APICBase base; ///
		alias base this;

		ubyte id; ///
		private ubyte reserved;
		PhysAddress32 address; ///
		uint globalSystemInterruptBase; ///
	}

	///
	struct InterruptSourceOverride {
		APICBase base; ///
		alias base this;

		ubyte busSource; ///
		ubyte irqSource; ///
		uint globalSystemInterrupt; ///
		ushort flags; ///
	}

	struct EntryRange {
		VirtAddress current;
		VirtAddress neverAbove;

		@property bool empty() {
			return current >= neverAbove;
		}

		@property APICBase* front() {
			return current.ptr!APICBase;
		}

		void popFront() {
			current += front.size;
		}
	}

align(1):
	SDTHeader base; ///
	alias base this;

	uint localControllerAddress; ///
	uint flags; /// 1 = Dual 8259 Legacy PICs Installed

	@property EntryRange entries() {
		VirtAddress vThis = VirtAddress(&this);
		return EntryRange(vThis + MADT.sizeof, vThis + base.length);
	}
}

///
@safe static struct ACPI {
public static: ///
	void initOld(ubyte[] rsdpData) @trusted {
		RSDPv1* rsdp = &(cast(RSDPv1[])rsdpData)[0];
		assert(rsdp.revision == 0, "RSDP is not version 1.0!");

		Log.info("ACPI/RSDP OEM is: ", rsdp.oemID[0 .. 6]);

		RSDTv1* rsdt = rsdp.rsdtAddress.toX64.VirtAddress.ptr!RSDTv1;
		assert(rsdt.valid);
		rsdt.print();

		_createLookupTable(SDTNeedVersion.v1Only);

		foreach (PhysAddress32 pSDT; rsdt.otherSDT) {
			SDTHeader* sdt = pSDT.toX64.toVirtual.ptr!SDTHeader;
			if (!sdt.valid)
				Log.error("SDT [", sdt, "] has an invalid checksum!");
			sdt.print();
			_runHandler(sdt);
		}
	}

	///
	void initNew(ubyte[] rsdpData) @trusted {
		RSDPv2* rsdp = &(cast(RSDPv2[])rsdpData)[0];
		assert(rsdp.revision >= 2, "RSDP is not >= version 2.0!");

		Log.info("ACPI/RSDP OEM is: ", rsdp.oemID[0 .. 6]);

		RSDTv2* rsdt = rsdp.xsdtAddress.VirtAddress.ptr!RSDTv2;
		assert(rsdt.valid);
		rsdt.print();

		_createLookupTable(SDTNeedVersion.v2Only);

		foreach (PhysAddress pSDT; rsdt.otherSDT) {
			SDTHeader* sdt = pSDT.toVirtual.ptr!SDTHeader;
			if (!sdt.valid)
				Log.error("SDT [", sdt, "] has an invalid checksum!");
			sdt.print();
			_runHandler(sdt);
		}
	}

	///
	@SDTIdentifier("FACP", SDTNeedVersion.v1Only)
	void accept(FADTv1* fadt) {
		import io.ioport : outp, inp;
		import arch.amd64.pit : PIT;
		import data.text : HexInt;

		_powerData.pm1aControlBlock = cast(ushort)fadt.pm1aControlBlock;
		_powerData.pm1bControlBlock = cast(ushort)fadt.pm1bControlBlock;

		// Enabling ACPI (if possible)
		if (fadt.smiCommandPort && fadt.acpiEnable && fadt.acpiDisable && !inp!PM1ControlBlock(cast(ushort)fadt.pm1aControlBlock).sciEnable) {
			outp!ubyte(cast(ushort)fadt.smiCommandPort, fadt.acpiEnable);

			size_t counter;
			while (!inp!PM1ControlBlock(cast(ushort)fadt.pm1aControlBlock).sciEnable && counter++ < 300)
				PIT.sleep(10);

			if (fadt.pm1bControlBlock)
				while (inp!PM1ControlBlock(cast(ushort)fadt.pm1bControlBlock).sciEnable && counter++ < 300)
					PIT.sleep(10);

			if (counter >= 300)
				Log.fatal("Failed to turn on ACPI!");
		}

		Log.info("ACPI is now on!");

		{
			DSDT* dsdt = fadt.dsdt.toX64.toVirtual.ptr!DSDT;
			if (!dsdt)
				return;
			if (!dsdt.valid)
				return Log.error("SDT [DSDT] has an invalid checksum!");

			dsdt.print();
			accept(dsdt);
		}
	}

	///
	@SDTIdentifier("FACP", SDTNeedVersion.v2Only)
	void accept(FADTv2* fadt) {
		import io.ioport : outp, inp;
		import arch.amd64.pit : PIT;

		_powerData.pm1aControlBlock = cast(ushort)fadt.xPM1aControlBlock.address;
		_powerData.pm1bControlBlock = cast(ushort)fadt.xPM1bControlBlock.address;

		_powerData.resetReg = fadt.resetReg;
		_powerData.resetValue = fadt.resetValue;

		// Enabling ACPII (if possible)
		if (fadt.smiCommandPort && fadt.acpiEnable && fadt.acpiDisable
				&& !inp!PM1ControlBlock(cast(ushort)fadt.xPM1aControlBlock.address).sciEnable) {
			outp!ubyte(cast(ushort)fadt.smiCommandPort, fadt.acpiEnable);

			size_t counter;
			while (!inp!PM1ControlBlock(cast(ushort)fadt.xPM1aControlBlock.address).sciEnable && counter++ < 300)
				PIT.sleep(10);

			if (fadt.xPM1bControlBlock.address)
				while (!inp!PM1ControlBlock(cast(ushort)fadt.xPM1bControlBlock.address).sciEnable && counter++ < 300)
					PIT.sleep(10);

			if (counter >= 300)
				Log.fatal("Failed to turn on ACPI!");
		}

		Log.info("ACPI is now on!");

		{
			DSDT* dsdt = fadt.xDSDT.toVirtual.ptr!DSDT;
			if (!dsdt)
				return;
			if (!dsdt.valid)
				return Log.error("SDT [DSDT] has an invalid checksum!");

			dsdt.print();
			accept(dsdt);
		}
	}

	/// This one doesn't really need the SDTIdentifier because it won't find it inside that list
	/// DSDT is aquired from FADTv1 or FADTv2
	@SDTIdentifier("DSDT", SDTNeedVersion.any)
	void accept(DSDT* dsdt) {
		import arch.amd64.aml : AMLOpcodes;
		import data.text : indexOf;

		ubyte[] data = dsdt.amlData();

		long idx;
		// Find: AMLOpcodes.nameOP '\\'? "_S5_" AMLOpcodes.packageOP
		while (idx >= 0) {
			// Start to search for the static part "_S5_" AMLOpcodes.packageOP.
			// Searching for packageOP because it is (hopefully) more unique than '_'
			idx = indexOf(data, cast(char)AMLOpcodes.packageOP, idx);
			if (data[idx - 4 .. idx + 1] == "_S5_\x12") // x12 = AMLOpcodes.packageOP
				if (data[idx - 5] == AMLOpcodes.nameOP || (data[idx - 6] == AMLOpcodes.nameOP && data[idx - 5] == '\\'))
					break;
			idx++;
		}

		if (idx < 0)
			Log.fatal("DSDT does not contain a _S5_");
		idx++;

		const ubyte pkgLength = (data[0] & 0xC0 >> 6) + 2;
		idx += pkgLength;

		if (data[idx] == AMLOpcodes.bytePrefix)
			idx++; // skip byteprefix
		_powerData.sleepTypeA = cast(ushort)(cast(ushort)data[idx] << 10);
		idx++;

		if (data[idx] == AMLOpcodes.bytePrefix)
			idx++; // skip byteprefix
		_powerData.sleepTypeB = cast(ushort)(cast(ushort)data[idx] << 10);
	}

	///
	@SDTIdentifier("APIC", SDTNeedVersion.any)
	void accept(MADT* madt) @trusted {
		with (MADT) {
			foreach (APICBase* entry; madt.entries) {
				switch (entry.type) with (APICBase.Type) {
				case processorLocalAPIC:
					LAPIC* lAPIC = cast(LAPIC*)entry;
					Log.info("Type: ", lAPIC.type, ", Length: ", lAPIC.size, ", ACPI ID: ", lAPIC.acpiID, ", APIC ID: ",
							lAPIC.apicID, ", Flags: ", lAPIC.flags);
					break;

				case processorLocalX2APIC:
					X2LAPIC* x2LAPIC = cast(X2LAPIC*)entry;
					Log.info("Type: ", x2LAPIC.type, ", Length: ", x2LAPIC.size, ", X2APIC ID: ", x2LAPIC.x2apicID, ", Flags: ",
							x2LAPIC.flags, ", ACPI ID: ", x2LAPIC.acpiID);
					break;

				case ioAPIC:
					IOAPIC* ioACPI = cast(IOAPIC*)entry;
					Log.info("Type: ", ioACPI.type, ", Length: ", ioACPI.size, ", ID: ", ioACPI.id, ", Address: ",
							ioACPI.address, ", GlobalSystemInterruptBase: ", ioACPI.globalSystemInterruptBase);
					break;

				case interruptSourceOverride:
					InterruptSourceOverride* interruptSourceOverride = cast(InterruptSourceOverride*)entry;
					Log.info("Type: ", interruptSourceOverride.type, ", Length: ", interruptSourceOverride.size, ", BusSource: ",
							interruptSourceOverride.busSource, ", IRQSource: ",
							interruptSourceOverride.irqSource, ", GlobalSystemInterrupt: ",
							interruptSourceOverride.globalSystemInterrupt, ", Flags: ", interruptSourceOverride.flags);
					break;

				default:
					Log.info("Type: ", entry.type, ", Length: ", entry.size);
					break;
				}
			}
		}
	}

	///
	void shutdown() {
		import io.ioport : outp, inp;
		import data.text : HexInt;
		import io.vga : VGA;

		asm @trusted pure nothrow {
			cli;
		}

		ushort orgData = inp!ushort(_powerData.pm1aControlBlock);

		Log.info("sleepEnable: ", _powerData.sleepEnable.HexInt, ", sleepTypeA: ", _powerData.sleepTypeA.HexInt,
				", sleepTypeB: ", _powerData.sleepTypeB.HexInt);

		VGA.writeln("sleepEnable: ", _powerData.sleepEnable.HexInt, ", sleepTypeA: ", _powerData.sleepTypeA.HexInt,
				", sleepTypeB: ", _powerData.sleepTypeB.HexInt);

		outp!ushort(_powerData.pm1aControlBlock, orgData | _powerData.sleepEnable | _powerData.sleepTypeA);
		if (_powerData.pm1bControlBlock) {
			orgData = inp!ushort(_powerData.pm1bControlBlock);
			outp!ushort(_powerData.pm1bControlBlock, orgData | _powerData.sleepEnable | _powerData.sleepTypeB);
		}

		{
			import io.vga : VGA, CGAColor, CGASlotColor;

			string resetMessage = "All attempts to shutdown have failed. Please shutdown the PC manually!";
			VGA.color = CGASlotColor(CGAColor.black, CGAColor.red);
			VGA.writeln(resetMessage);
			Log.fatal(resetMessage);
		}
	}

	///
	void reboot() {
		import io.ioport : inp, outp;

		asm @trusted pure nothrow {
			cli;
		}

		with (_powerData) {
			if (resetReg.address) {
				Log.debug_("Trying ACPIv2.0+ reset...");
				switch (resetReg.addressSpace) with (FADTv2.GenericAddressStructure.AddressSpace) {
				case systemMemory:
					*resetReg.address.toVirtual.ptr!ubyte = resetValue;
					break;
				case systemIO:
					outp!ubyte(cast(ushort)resetReg.address.num, resetValue);
					break;
				case pciConfigurationSpace:
					Log.fatal("TODO: pciConfigurationSpace rebooting is not implemented!");
					break;
				default:
					break;
				}
			}
		}

		Log.debug_("Trying PS/2 reset...");
		enum ushort ps2PortControl = 0x64;
		enum ushort ps2PortData = 0x60;
		enum ubyte systemReset = 0xFE;
		ubyte tmp = void;

		// Check that the input buffer is empty
		do {
			tmp = inp!ubyte(ps2PortControl);
			if (tmp & 0x1)
				inp!ubyte(ps2PortData);
		}
		while (tmp & 0x3);

		Log.debug_("\tSending reset!");
		outp!ubyte(ps2PortControl, systemReset);

		{
			import io.vga : VGA, CGAColor, CGASlotColor;

			string resetMessage = "All attempts to reboot have failed. Please reset the PC manually!";
			VGA.color = CGASlotColor(CGAColor.black, CGAColor.red);
			VGA.writeln(resetMessage);
			Log.fatal(resetMessage);
		}
	}

private static:
	struct PowerData {
		ushort pm1aControlBlock;
		ushort pm1bControlBlock;
		ushort sleepTypeA;
		ushort sleepTypeB;
		ushort sleepEnable = 1 << 13;

		FADTv2.GenericAddressStructure resetReg;
		ubyte resetValue;
	}

	enum SDTNeedVersion {
		any,
		v1Only,
		v2Only
	}

	struct SDTIdentifier {
		char[4] name;
		SDTNeedVersion versionRequirement = SDTNeedVersion.any;
	}

	struct SDTLookup {
		char[4] name;
		void function(SDTHeader*) func;
	}

	@property ref PowerData _powerData() @trusted {
		__gshared PowerData _powerData;
		return _powerData;
	}

	__gshared SDTLookup[{ return from!"util.trait".getFunctionsWithUDA!(ACPI, SDTIdentifier).length; }()] _lookups;

	void _runHandler(SDTHeader* sdt) @trusted {
		foreach (lookup; _lookups) {
			if (sdt.signature[0 .. 4] == lookup.name[0 .. 4])
				return lookup.func(sdt);
		}
	}

	void _createLookupTable(SDTNeedVersion versionRequirement) @trusted {
		import util.trait : getFunctionsWithUDA;

		size_t lookupID;

		alias handlers = getFunctionsWithUDA!(ACPI, SDTIdentifier);
		foreach (idx, handler; handlers) {
			static if (!is(typeof(handler) == SDTIdentifier)) {
				assert(lookupID < _lookups.length);

				SDTIdentifier uda = handlers[idx + 1];
				if (uda.versionRequirement == SDTNeedVersion.any || uda.versionRequirement == versionRequirement) {
					_lookups[lookupID].name = uda.name;
					_lookups[lookupID].func = cast(typeof(SDTLookup.func))&handler;
					lookupID++;
				}
			}
		}
	}

}
