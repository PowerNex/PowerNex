/**
 * The filesystem base types
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.supernode;

import fs;

/**
 * The vtable for FSSuperNode.
 * See_Also:
 *    FSSuperNode
 */
@safe struct FSSuperNodeVTable {
	/**
	 * Prototype of FSSuperNode.getNode.
	 * See_Also:
	 *    FSSuperNode.getNode
	 */
	FSNode* function(ref FSSuperNode supernode, FSNode.ID id) getNode;

	/**
	 * Prototype of FSSuperNode.saveNode.
	 * See_Also:
	 *    FSSuperNode.saveNode
	 */
	void function(ref FSSuperNode supernode, const ref FSNode node) saveNode;

	/**
	 * Prototype of FSSuperNode.addNode.
	 * See_Also:
	 *    FSSuperNode.addNode
	 */
	FSNode* function(ref FSSuperNode supernode, ref FSNode parent, FSNode.Type type, string name) addNode;

	/**
	 * Prototype of FSSuperNode.removeNode.
	 * See_Also:
	 *    FSSuperNode.removeNode
	 */
	bool function(ref FSSuperNode supernode, ref FSNode parent, FSNode.ID id) removeNode;

	/**
	 * Prototype of FSSuperNode.getFreeNodeID.
	 * See_Also:
	 *    FSSuperNode.getFreeNodeID
	 */
	FSNode.ID function(ref FSSuperNode supernode) getFreeNodeID;

	/**
	 * Prototype of FSSuperNode.getFreeBlockID.
	 * See_Also:
	 *    FSSuperNode.getFreeBlockID
	 */
	FSBlockDevice.BlockID function(ref FSSuperNode supernode) getFreeBlockID;

	/**
	 * Prototype of FSSuperNode.setBlockUsed.
	 * See_Also:
	 *    FSSuperNode.setBlockUsed
	 */
	void function(ref FSSuperNode supernode, FSBlockDevice.BlockID id) setBlockUsed;

	/**
	 * Prototype of FSSuperNode.setBlockFree.
	 * See_Also:
	 *    FSSuperNode.setBlockFree
	 */
	void function(ref FSSuperNode supernode, FSBlockDevice.BlockID id) setBlockFree;
}

/**
 * The supernode type.
 */
@safe struct FSSuperNode {
	pragma(inline, true):

	/// Internal vtable stuff
	const FSSuperNodeVTable* vtable;

	/// Where to get the data from
	FSBlockDevice* blockdevice;

	@disable this();
	this(const FSSuperNodeVTable* vtable) {
		this.vtable = vtable;
	}

	/**
	 * Get the node corresponding to the \a id.
	 * Params:
	 *      id The index
	 * Returns: The node
	 * See_Also:
	 *    FSSuperNode
	 */
	FSNode* getNode(FSNode.ID id) {
		return vtable.getNode(this, id);
	}

	/**
	 * Save the changes of a node to disk.
	 * Params:
	 *      node The node to save
	 * See_Also:
	 *    FSSuperNode
	 */
	void saveNode(const ref FSNode node) {
		vtable.saveNode(this, node);
	}

	/**
	 * Create a new node.
	 * Params:
	 *      parent The parent for the new node
	 *      type The type for the new node
	 *      name The name for the new node
	 * Returns: The new node
	 * See_Also:
	 *    FSSuperNode
	 */
	FSNode* addNode(ref FSNode parent, FSNode.Type type, string name) {
		return vtable.addNode(this, parent, type, name);
	}

	/**
	 * Remove a node.
	 * Params:
	 *      parent The parent for the node
	 *      id The node id
	 * Returns: If the removal was successful
	 * See_Also:
	 *    FSSuperNode
	 */
	bool removeNode(ref FSNode parent, FSNode.ID id) {
		return vtable.removeNode(this, parent, id);
	}

	/**
	 * Get a free node id
	 * Params:
	 * Returns: The free node id, 0 if it failed
	 * See_Also:
	 *    FSSuperNode
	 */
	FSNode.ID getFreeNodeID() {
		return vtable.getFreeNodeID(this);
	}

	/**
	 * Get a free block id
	 * Params:
	 * Returns: The free block id, 0 if it failed
	 * See_Also:
	 *    FSSuperNode
	 */
	FSBlockDevice.BlockID getFreeBlockID() {
		return vtable.getFreeBlockID(this);
	}

	/**
	 * Set a block status as used.
	 * Params:
	 *      id The block id
	 * See_Also:
	 *    FSSuperNode
	 */
	void setBlockUsed(FSBlockDevice.BlockID id) {
		return vtable.setBlockUsed(this, id);
	}

	/**
	 * Set a block status as free.
	 * Params:
	 *      id The block id
	 * See_Also:
	 *    FSSuperNode
	 */
	void setBlockFree(FSBlockDevice.BlockID id) {
		return vtable.setBlockFree(this, id);
	}
}
