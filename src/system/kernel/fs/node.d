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
 * The vtable for FSNode
 * See_Also:
 *    FSNode
 */
@safe struct FSNodeVTable {
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
	FSDirectoryEntry[] function(ref FSNode node) directoryEntries;

	/**
	 * Prototype of FSNode.findNode.
	 * See_Also:
	 *  FSNode.findNode
	 */
	FSNode* function(ref FSNode node, string path) findNode;

	/**
	 * Prototype of FSNode.getName.
	 * See_Also:
	 *  FSNode.getName
	 */
	string function(ref FSNode node, ref FSNode parent) getName;

	/**
	 * Prototype of FSNode.getParent.
	 * See_Also:
	 *    FSNode.getParent
	 */
	FSNode* function(ref FSNode node, ref FSNode directory) getParent;
}

/**
 * The node type.
 */
struct FSNode {
	/**
	 * The node index type.
	 * See_Also:
	 *    FSNode
	 */
	alias ID = ulong;

	/// Invalid node id
	enum ID invalid = 0;
	/// The id for the root node
	enum ID root = 1;

	/**
	 * The different node types.
	 */
	enum Type {
		/// Invalid type
		invalid = 0,
		/// File type
		file,
		/// Directory type
		directory,

		/// Will never be valid, Only used for node
		/// See_Also: Node.invalid
		neverValid
	}

	/// Internal vtable stuff
	const FSNodeVTable* vtable;

	/// The owner
	FSSuperNode* superNode;

	/// The node id
	ID id;

	/// What type the node is
	Type type;

	/// The size
	ulong size;

	/// The amount of nodes it uses
	ulong blockCount;

	@disable this();
	this(const FSNodeVTable* vtable) {
		this.vtable = vtable;
	}

	/**
 * Read data from the node.
 * Params:
 *      buffer Where to write the data to
 *      offset Where to start in the node
 * Returns: The amount of data read
 * See_Also:
 *    FSNode
 */
	ulong readData(ref ubyte[] buffer, ulong offset) {
		return vtable.readData(this, buffer, offset);
	}

	/**
 * Write data to the node.
 * Params:
 *      buffer Where to read the data from
 *      offset Where to start in the node
 * Returns: The amount of data written
 * See_Also:
 *    FSNode
 */
	ulong writeData(const ref ubyte[] buffer, ulong offset) {
		return vtable.writeData(this, buffer, offset);
	}

	/**
 * Get a array of all the entries in a directory
 * Params:
 *      amount Returns how big the array is
 * Returns: The directory entry array, if the node is of the type FSNode.Type.directory, else NULL
 * See_Also:
 *    FSNode
 */
	FSDirectoryEntry[] directoryEntries() {
		return vtable.directoryEntries(this);
	}

	/**
 * Search for a node based on the \a path.
 * The path be both absolute or relative.
 * Params:
 *      path The path to be searched
 * Returns: The node it found else NULL
 * See_Also:
 *    FSNode
 */
	FSNode* findNode(string path) {
		return vtable.findNode(this, path);
	}

	/**
 * Get the name a of node.
 * Params:
 *      parent The parent for that node
 * Returns: The name or NULL
 * See_Also:
 *    FSNode
 */
	string getName(ref FSNode parent) {
		return vtable.getName(this, parent);
	}

	/**
 * Get the parent for a directory node.
 * Params:
 *      directory The directory
 * Returns: The parent for that node
 * See_Also:
 *    FSNode
 */
	FSNode* getParent(ref FSNode directory) {
		return vtable.getParent(this, directory);
	}

	//TODO: Add resize
}

struct FSDirectoryEntry {
	/// The id for the entry
	FSNode.ID id;
	/// The name for the entry
	char[62] name;
}
