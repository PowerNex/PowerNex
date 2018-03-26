/**
 * The filesystem base types
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.block;

import fs;

/**
 * The block representation struct.
 * It contains a byte array that define how big each block is.
 */
@safe struct FSBlock {
	/**
	 * The size of each block.
	 */
	enum blockSize = 0x1000 / 4;

	/// The data
	ubyte[blockSize] data;
}

@safe struct FSBlockDeviceVTable {
	/**
	 * Prototype of FSBlockDevice.readD
	 * See_Also:
	 *  FSBlockDevice.read
	 */
	void function(ref FSBlockDevice bd, FSBlockDevice.BlockID idx, ref FSBlock block) read;

	/**
	 * Prototype of FSBlockDevice.readD
	 * See_Also:
	 *  FSBlockDevice.read
	 */
	void function(ref FSBlockDevice bd, FSBlockDevice.BlockID idx, const ref FSBlock block) write;
}

/**
 * Helper class for writing and reading blocks from the file.
 */
@safe struct FSBlockDevice {
pragma(inline, true):
	/**
	 * The block index type.
	 */
	alias BlockID = ulong;

	const FSBlockDeviceVTable* vtable;

	@disable this();
	this(const FSBlockDeviceVTable* vtable) {
		this.vtable = vtable;
	}

	/**
	 * This functions reads a block at the index \a idx from the blockdevice and writes the data to \a block.
	 * Params:
	 *      idx The blocks index
	 *      block Where to write the block to
	 * See_Also:
	 *    FSBlockDevice
	 *    FSBlock
	 */
	void read(FSBlockDevice.BlockID idx, ref FSBlock block) {
		vtable.read(this, idx, block);
	}

	/**
	 * This functions writes the block \a block to the index \a idx in the blockdevice.
	 * Params:
	 *      idx The blocks index
	 *      block The block
	 * See_Also:
	 *    FSBlockDevice
	 *    FSBlock
	 */
	void write(FSBlockDevice.BlockID idx, const ref FSBlock block) {
		vtable.write(this, idx, block);
	}
}
