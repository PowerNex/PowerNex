module api;
public import api.base;

private extern extern (C) __gshared PowerDHeader powerDHeader;

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

private static __gshared:

}
