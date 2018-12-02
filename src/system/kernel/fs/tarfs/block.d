/**
 * The filesystem base
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.tarfs.block;

import fs.tarfs;

import stl.address;
import stl.io.log;
import stl.vmm.heap;

@safe struct TarFSBlockDevice {
	import stl.address : VirtMemoryRange;

	FSBlockDevice base;
	alias base this;

	VirtMemoryRange data;

	this(VirtMemoryRange range) {
		data = range;
		with (base) {
			readBlock = &this.readBlock;
			writeBlock = &this.writeBlock;
			getBlockCount = &this.getBlockCount;
		}
	}

	void readBlock(FSBlockDevice.BlockID idx, ref FSBlock block) {
		Log.error("TarFSBlockDevice.readBlock: ", idx);
		block = FSBlock();
	}

	void writeBlock(FSBlockDevice.BlockID idx, const ref FSBlock block) {
		Log.error("TarFSBlockDevice.writeBlock: ", idx);
	}

	size_t getBlockCount() {
		Log.error("TarFSBlockDevice.getBlockCount: ");
		return 0;
	}
}
