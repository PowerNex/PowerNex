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
	FSNode*[] activeMountPoints;

	/**
	 * Get the node corresponding to the \a id.
	 * Params:
	 *      id The index
	 * Returns: The node
	 */

	FSNode* delegate(FSNode.ID id) getNode;

	/**
	 * Save the changes of a node to disk.
	 * Params:
	 *      node The node to save
	 */

	void delegate(const ref FSNode node) saveNode;

	/**
	 * Create a new node.
	 * Params:
	 *      parent The parent for the new node
	 *      type The type for the new node
	 *      name The name for the new node
	 * Returns: The new node
	 */

	FSNode* delegate(ref FSNode parent, FSNode.Type type, string name) addNode;

	/**
	 * Remove a node.
	 * Params:
	 *      parent The parent for the node
	 *      id The node id
	 * Returns: If the removal was successful
	 */

	bool delegate(ref FSNode parent, FSNode.ID id) removeNode;

	/**
	 * Get a free node id
	 * Params:
	 * Returns: The free node id, 0 if it failed
	 */

	FSNode.ID delegate() getFreeNodeID;

	/**
	 * Get a free block id
	 * Params:
	 * Returns: The free block id, 0 if it failed
	 */

	FSBlockDevice.BlockID delegate() getFreeBlockID;

	/**
	 * Set a block status as used.
	 * Params:
	 *      id The block id
	 */
	void delegate(FSBlockDevice.BlockID id) setBlockUsed;

	/**
	 * Set a block status as free.
	 * Params:
	 *      id The block id
	 */
	void delegate(FSBlockDevice.BlockID id) setBlockFree;
}
