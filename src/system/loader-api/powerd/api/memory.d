/**
 * This handles the API interface for the memory data structures.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module powerd.api.memory;

import stl.address;

/// The PowerD memory information container
@safe struct PowerDMemory {
	ulong maxFrames; ///
	ulong usedFrames; ///
	ulong[] bitmaps; ///
	ulong currentBitmapIdx; ///
}
