/**
 * This handles the API interface for the PowerD data structures.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module api.base;

import data.address;

/// SymVer version format: Major.Minor.Patch
struct Version {
	// TODO: Change to a smaller unsigned interger container?
	size_t major; /// The major version
	size_t minor; /// The minor version
	size_t patch; /// The patch version
}

/// The PowerD information container
struct PowerDHeader {
	enum size_t magicValue = 0x3056_4472_6577_6F50UL; /// "PowerDV0" as size_t (backwards because of little-endian)
	size_t magic; /// The magic
	Version version_; /// The PowerD version
}
