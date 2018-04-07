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
 * The supernode type.
 */
@safe struct FSSuperNode {
	/// The vtable for FSSuperNode.
	struct VTable {
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

	/// Internal vtable stuff
	const(VTable)* vtable;

	FSNode*[] activeMountPoints;

	@disable this();
	this(const(VTable)* vtable) {
		this.vtable = vtable;
	}

pragma(inline, true):
	/**
	 * Get the node corresponding to the \a id.
	 * Params:
	 *      id The index
	 * Returns: The node
	 */
	FSNode* getNode(FSNode.ID id) {
		assert(vtable.getNode, "vtable.getNode is null!");
		return vtable.getNode(this, id);
	}

	/**
	 * Save the changes of a node to disk.
	 * Params:
	 *      node The node to save
	 */
	void saveNode(const ref FSNode node) {
		assert(vtable.saveNode, "vtable.saveNode is null!");
		vtable.saveNode(this, node);
	}

	/**
	 * Create a new node.
	 * Params:
	 *      parent The parent for the new node
	 *      type The type for the new node
	 *      name The name for the new node
	 * Returns: The new node
	 */
	FSNode* addNode(ref FSNode parent, FSNode.Type type, string name) {
		assert(vtable.addNode, "vtable.addNode is null!");
		return vtable.addNode(this, parent, type, name);
	}

	/**
	 * Remove a node.
	 * Params:
	 *      parent The parent for the node
	 *      id The node id
	 * Returns: If the removal was successful
	 */
	bool removeNode(ref FSNode parent, FSNode.ID id) {
		assert(vtable.removeNode, "vtable.removeNode is null!");
		return vtable.removeNode(this, parent, id);
	}

	/**
	 * Get a free node id
	 * Params:
	 * Returns: The free node id, 0 if it failed
	 */
	FSNode.ID getFreeNodeID() {
		assert(vtable.getFreeNodeID, "vtable.getFreeNodeID is null!");
		return vtable.getFreeNodeID(this);
	}

	/**
	 * Get a free block id
	 * Params:
	 * Returns: The free block id, 0 if it failed
	 */
	FSBlockDevice.BlockID getFreeBlockID() {
		assert(vtable.getFreeBlockID, "vtable.getFreeBlockID is null!");
		return vtable.getFreeBlockID(this);
	}

	/**
	 * Set a block status as used.
	 * Params:
	 *      id The block id
	 */
	void setBlockUsed(FSBlockDevice.BlockID id) {
		assert(vtable.setBlockUsed, "vtable.setBlockUsed is null!");
		return vtable.setBlockUsed(this, id);
	}

	/**
	 * Set a block status as free.
	 * Params:
	 *      id The block id
	 */
	void setBlockFree(FSBlockDevice.BlockID id) {
		assert(vtable.setBlockFree, "vtable.setBlockFree is null!");
		return vtable.setBlockFree(this, id);
	}
}
