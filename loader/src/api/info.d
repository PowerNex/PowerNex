module api.info;

import data.address;

enum size_t PowerDInfoMagic = 0x3056_4472_6577_6F50UL; /// "PowerDV0" as size_t (backwards because of little-endian)

/// SymVer version format: Major.Minor.Patch
struct Version {
	// TODO: Change to a smaller unsigned interger container?
	size_t major; /// The major version
	size_t minor; /// The minor version
	size_t patch; /// The patch version
}

/// The PowerD infomation container
struct PowerDInfo {
	size_t magic; /// The magic
	Version version_; /// The PowerD version
}

static assert(PowerDInfo.sizeof < 64, "Please update the size for PowerDInfo inside of loaderData.S!");