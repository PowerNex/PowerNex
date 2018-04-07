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

import stl.vtable;
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
	/// The vtable for FSBlockDevice.
	struct VTable {
		/**
		* Prototype of FSBlockDevice.readBlock
		* See_Also:
		*  FSBlockDevice.readBlock
		*/
		void function(ref FSBlockDevice bd, FSBlockDevice.BlockID idx, ref FSBlock block) readBlock;

		/**
		* Prototype of FSBlockDevice.writeBlock
		* See_Also:
		*  FSBlockDevice.writeBlock
		*/
		void function(ref FSBlockDevice bd, FSBlockDevice.BlockID idx, const ref FSBlock block) writeBlock;

		/**
		* Prototype of FSBlockDevice.getBlockCount
		* See_Also:
		*  FSBlockDevice.getBlockCount
		*/
		size_t function(ref FSBlockDevice bd) getBlockCount;
	}


	/**
	 * The block index type.
	 */
	alias BlockID = ulong;

	const(VTable)* vtable;

	@disable this();
	this(const(VTable)* vtable) {
		this.vtable = vtable;
	}

pragma(inline, true):

	/**
	 * This functions reads a block at the index \a idx from the blockdevice and writes the data to \a block.
	 * Params:
	 *      idx The blocks index
	 *      block Where to write the block to
	 * See_Also:
	 *    FSBlock
	 */
	void readBlock(FSBlockDevice.BlockID idx, ref FSBlock block) {
		assert(vtable.readBlock, "vtable.readBlock is null!");
		vtable.readBlock(this, idx, block);
	}

	/**
	 * This functions writes the block \a block to the index \a idx in the blockdevice.
	 * Params:
	 *      idx The blocks index
	 *      block The block
	 * See_Also:
	 *    FSBlock
	 */
	void writeBlock(FSBlockDevice.BlockID idx, const ref FSBlock block) {
		assert(vtable.writeBlock, "vtable.writeBlock is null!");
		vtable.writeBlock(this, idx, block);
	}

	/**
	 * Prototype of FSBlockDevice.getBlockCount
	 */
	size_t getBlockCount() {
		assert(vtable.getBlockCount, "vtable.getBlockCount is null!");
		return vtable.getBlockCount(this);
	}

	/**
	 * Prototype of FSBlockDevice.getBlockCount
	 */
	size_t getSuperNode() {
		assert(vtable.getBlockCount, "vtable.getBlockCount is null!");
		return vtable.getBlockCount(this);
	}
}
