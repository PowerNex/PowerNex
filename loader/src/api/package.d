module api;
public import api.base;
public import api.acpi;

private extern extern (C) __gshared PowerDHeader powerDHeader;
private extern extern (C) __gshared PowerDACPI powerDACPI;

@safe static struct APIInfo {
public static:
	void init() {
		header = PowerDHeader.init;
		with (header) {
			magic = PowerDHeader.magicValue;
			version_ = Version(0, 0, 0); // TODO: Sync with init32.S somehow
		}
	}

	@property ref PowerDHeader header() @trusted {
		return .powerDHeader;
	}

	@property ref PowerDACPI acpi() @trusted {
		return .powerDACPI;
	}
}
