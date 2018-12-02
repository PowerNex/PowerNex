/**
 * The filesystem base types
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.node;

import fs;

/**
 * The node type.
 */
@safe struct FSNode {
	/**
	 * The node index type.
	 * See_Also:
	 *    FSNode
	 */
	alias ID = ulong;

	/**
	 * The different node types.
	 */
	enum Type : ulong {
		/// These types will be saved to disk

		/// Not in use type
		notInUse = 0,
		/// File type
		file,
		/// Directory type
		directory,
		/// Symbolic link type
		symbolicLink,
		/// Hard link type
		hardLink,

		/// These types won't be saved to disk

		/// Only valid during runtime
		mountpoint = 0x1000,

		unknown = ulong.max
	}

	/// The owner
	FSSuperNode* superNode;

	/// The node id
	ID id;

	/// What type the node is
	Type type;

	/// The size
	ulong size;

	/// The amount of nodes it uses
	/// ulong.max = N/A
	ulong blockCount;

	/**
	 * Read data from the node.
	 * Params:
	 *      buffer Where to write the data to
	 *      offset Where to start in the node
	 * Returns: The amount of data read
	 */
	ulong delegate(ref ubyte[] buffer, ulong offset) readData;

	/**
	 * Write data to the node.
	 * Params:
	 *      buffer Where to read the data from
	 *      offset Where to start in the node
	 * Returns: The amount of data written
	 */
	ulong delegate(const ref ubyte[] buffer, ulong offset) writeData;

	/**
	 * Get a array of all the entries in a directory
	 * Params:
	 *      amount Returns how big the array is
	 * Returns: The directory entry array, if the node is of the type FSNode.Type.directory, else NULL
	 */
	FSDirectoryEntry[]delegate() directoryEntries;

	/**
	 * Search for a node based on the \a path.
	 * The path be both absolute or relative.
	 * Params:
	 *      path The path to be searched
	 * Returns: The node it found else NULL
	 */
	FSNode* delegate(string path) findNode;

	/**
	 * Link in a node in directory
	 * Params:
	 *      name The name of the link
	 *      id The node id
	 */
	void delegate(string name, FSNode.ID id) link;

	//TODO: Add resize
}

@safe struct FSDirectoryEntry {
	/// The id for the entry
	FSNode.ID id;
	/// The name for the entry
	char[62] name;

	@property string nameStr() const {
		import stl.text : fromStringz;

		return name.fromStringz;
	}
}
