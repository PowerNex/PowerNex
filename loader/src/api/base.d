module api.base;

import data.address;

/// SymVer version format: Major.Minor.Patch
struct Version {
	// TODO: Change to a smaller unsigned interger container?
	size_t major; /// The major version
	size_t minor; /// The minor version
	size_t patch; /// The patch version
}

/// The PowerD infomation container
struct PowerDHeader {
	enum size_t magicValue = 0x3056_4472_6577_6F50UL; /// "PowerDV0" as size_t (backwards because of little-endian)
	size_t magic; /// The magic
	Version version_; /// The PowerD version
}

static assert(PowerDHeader.sizeof < 64, "Please update the size for PowerDHeader inside of loaderData.S!");
