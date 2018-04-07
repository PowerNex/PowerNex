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

import stl.vtable;
import stl.address;
import stl.io.log;
import stl.vmm.heap;

// dfmt off
private __gshared const FSBlockDevice.VTable TarFSBlockDeviceVTable = {
	readBlock: VTablePtr!(typeof(FSBlockDevice.VTable.readBlock))(&TarFSBlockDevice.readBlock),
	writeBlock: VTablePtr!(typeof(FSBlockDevice.VTable.writeBlock))(&TarFSBlockDevice.writeBlock),
	getBlockCount: VTablePtr!(typeof(FSBlockDevice.VTable.getBlockCount))(&TarFSBlockDevice.getBlockCount)
};
// dfmt on

@safe struct TarFSBlockDevice {
	import stl.address: VirtMemoryRange;

	FSBlockDevice base = &TarFSBlockDeviceVTable;
	alias base this;

	VirtMemoryRange data;

	this(VirtMemoryRange range) {
		data = range;
	}

	static private {
		void readBlock(ref TarFSBlockDevice blockDevice, FSBlockDevice.BlockID idx, ref FSBlock block) {
			Log.error("TarFSBlockDevice.readBlock: ", idx);
			block = FSBlock();
		}

		void writeBlock(ref TarFSBlockDevice blockDevice, FSBlockDevice.BlockID idx, const ref FSBlock block) {
			Log.error("TarFSBlockDevice.writeBlock: ", idx);
		}

		size_t getBlockCount(ref TarFSBlockDevice blockDevice) {
			Log.error("TarFSBlockDevice.getBlockCount: ");
			return 0;
		}
	}
}
