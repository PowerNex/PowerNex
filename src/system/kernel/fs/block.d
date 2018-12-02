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

import stl.address;
import stl.io.log;
import stl.vmm.heap;

/**
 * The block representation struct.
 * It contains a byte array that define how big each block is.
 */
@safe struct FSBlock {
	/**
	 * The size of each block.
	 */
	enum blockSize = 0x1000;

	/// The data
	ubyte[blockSize] data;
}

/**
 * Helper class for writing and reading blocks from the file.
 */
@safe struct FSBlockDevice {
	/**
	 * The block index type.
	 */
	alias BlockID = ulong;

	/**
	 * This functions reads a block at the index \a idx from the blockdevice and writes the data to \a block.
	 * Params:
	 *      idx The blocks index
	 *      block Where to write the block to
	 * See_Also:
	 *    FSBlock
	 */
	void delegate(FSBlockDevice.BlockID idx, ref FSBlock block) readBlock;

	/**
	 * This functions writes the block \a block to the index \a idx in the blockdevice.
	 * Params:
	 *      idx The blocks index
	 *      block The block
	 * See_Also:
	 *    FSBlock
	 */
	void delegate(FSBlockDevice.BlockID idx, const ref FSBlock block) writeBlock;

	/**
		* Get the number of block the device have.
		*/
	size_t delegate() getBlockCount;
}
