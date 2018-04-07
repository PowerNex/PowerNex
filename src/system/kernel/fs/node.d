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
	 * The vtable for FSNode
	 */
	struct VTable {
		/**
		 * Prototype of FSNode.readData.
		 * See_Also:
		 *  FSNode.readData
		 */
		ulong function(ref FSNode node, ref ubyte[] buffer, ulong offset) readData;

		/**
		 * Prototype of FSNode.writeData.
		 * See_Also:
		 *  FSNode.writeData
		 */
		ulong function(ref FSNode node, const ref ubyte[] buffer, ulong offset) writeData;

		/**
		 * Prototype of FSNode.directoryEntries.
		 * See_Also:
		 *  FSNode.directoryEntries
		 */
		FSDirectoryEntry[]function(ref FSNode node) directoryEntries;

		/**
		 * Prototype of FSNode.findNode.
		 * See_Also:
		 *  FSNode.findNode
		 */
		FSNode* function(ref FSNode node, string path) findNode;

		/**
		 * Prototype of FSNode.link.
		 * See_Also:
		 *  FSNode.link
		 */
		void function(ref FSNode node, string name, FSNode.ID id) link;
	}

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

	/// Internal vtable stuff
	const(VTable)* vtable;

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

	@disable this();
	this(const(VTable)* vtable) {
		this.vtable = vtable;
	}

	/**
	 * Read data from the node.
	 * Params:
	 *      buffer Where to write the data to
	 *      offset Where to start in the node
	 * Returns: The amount of data read
	 */
	ulong readData(ref ubyte[] buffer, ulong offset) {
		assert(vtable.readData, "vtable.readData is null!");
		return vtable.readData(this, buffer, offset);
	}

	/**
	 * Write data to the node.
	 * Params:
	 *      buffer Where to read the data from
	 *      offset Where to start in the node
	 * Returns: The amount of data written
	 */
	ulong writeData(const ref ubyte[] buffer, ulong offset) {
		assert(vtable.writeData, "vtable.writeData is null!");
		return vtable.writeData(this, buffer, offset);
	}

	/**
	 * Get a array of all the entries in a directory
	 * Params:
	 *      amount Returns how big the array is
	 * Returns: The directory entry array, if the node is of the type FSNode.Type.directory, else NULL
	 */
	FSDirectoryEntry[] directoryEntries() {
		assert(vtable.directoryEntries, "vtable.directoryEntries is null!");
		return vtable.directoryEntries(this);
	}

	/**
	 * Search for a node based on the \a path.
	 * The path be both absolute or relative.
	 * Params:
	 *      path The path to be searched
	 * Returns: The node it found else NULL
	 */
	FSNode* findNode(string path) {
		assert(vtable.findNode, "vtable.findNode is null!");
		return vtable.findNode(this, path);
	}

	/**
	 * Link in a node in directory
	 * Params:
	 *      name The name of the link
	 *      id The node id
	 */
	void link(string name, FSNode.ID id) {
		assert(vtable.link, "vtable.link is null!");
		vtable.link(this, name, id);
	}

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
