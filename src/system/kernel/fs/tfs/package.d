/**
 * Implementation of a test filesystem
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.tfs;

import fs;
import stl.vtable;

// dfmt off
__gshared FSBlockDeviceVTable TFSBlockDeviceVTable = {
	read: VTablePtr!(typeof(FSBlockDeviceVTable.read))(&TFSBlockDevice.read),
	write: VTablePtr!(typeof(FSBlockDeviceVTable.write))(&TFSBlockDevice.write)
};
// dfmt on

@safe struct TFSBlockDevice {
	FSBlockDevice blockDevice = &TFSBlockDeviceVTable;

static:
	void read(ref TFSBlockDevice blockDevice, FSBlockDevice.BlockID idx, ref FSBlock block) {
	}

	void write(ref TFSBlockDevice blockDevice, FSBlockDevice.BlockID idx, const ref FSBlock block) {
	}
}

// dfmt off
__gshared FSSuperNodeVTable TFSSuperNodeVTable = {
	getNode: VTablePtr!(typeof(FSSuperNodeVTable.getNode))(&TFSSuperNode.getNode),
	saveNode: VTablePtr!(typeof(FSSuperNodeVTable.saveNode))(&TFSSuperNode.saveNode),
	addNode: VTablePtr!(typeof(FSSuperNodeVTable.addNode))(&TFSSuperNode.addNode),
	removeNode: VTablePtr!(typeof(FSSuperNodeVTable.removeNode))(&TFSSuperNode.removeNode),
	getFreeNodeID: VTablePtr!(typeof(FSSuperNodeVTable.getFreeNodeID))(&TFSSuperNode.getFreeNodeID),
	getFreeBlockID: VTablePtr!(typeof(FSSuperNodeVTable.getFreeBlockID))(&TFSSuperNode.getFreeBlockID),
	setBlockUsed: VTablePtr!(typeof(FSSuperNodeVTable.setBlockUsed))(&TFSSuperNode.setBlockUsed),
	setBlockFree: VTablePtr!(typeof(FSSuperNodeVTable.setBlockFree))(&TFSSuperNode.setBlockFree)
};
// dfmt on

@safe struct TFSSuperNode {
	FSSuperNode supernode = &TFSSuperNodeVTable;

static:
	FSNode* getNode(ref TFSSuperNode supernode, FSNode.ID id) {
		return null;
	}

	void saveNode(ref TFSSuperNode supernode, const ref FSNode node) {
	}

	FSNode* addNode(ref TFSSuperNode supernode, ref FSNode parent, FSNode.Type type, string name) {
		return null;
	}

	bool removeNode(ref TFSSuperNode supernode, ref FSNode parent, FSNode.ID id) {
		return false;
	}

	FSNode.ID getFreeNodeID(ref TFSSuperNode supernode) {
		return 0;
	}

	FSBlockDevice.BlockID getFreeBlockID(ref TFSSuperNode supernode) {
		return 0;
	}

	void setBlockUsed(ref TFSSuperNode supernode, FSBlockDevice.BlockID id) {
	}

	void setBlockFree(ref TFSSuperNode supernode, FSBlockDevice.BlockID id) {
	}

}

// dfmt off
__gshared FSNodeVTable TFSNodeVTable = {
	readData: VTablePtr!(typeof(FSNodeVTable.readData))(&TFSNode.readData),
	writeData: VTablePtr!(typeof(FSNodeVTable.writeData))(&TFSNode.writeData),
	directoryEntries: VTablePtr!(typeof(FSNodeVTable.directoryEntries))(&TFSNode.directoryEntries),
	findNode: VTablePtr!(typeof(FSNodeVTable.findNode))(&TFSNode.findNode),
	getName: VTablePtr!(typeof(FSNodeVTable.getName))(&TFSNode.getName),
	getParent: VTablePtr!(typeof(FSNodeVTable.getParent))(&TFSNode.getParent)
};
// dfmt on

@safe struct TFSNode {
	FSNode node = &TFSNodeVTable;

static:
	ulong readData(ref TFSNode node, ref ubyte[] buffer, ulong offset) {
		return 0;
	}

	ulong writeData(ref TFSNode node, const ref ubyte[] buffer, ulong offset) {
		return 0;
	}

	FSDirectoryEntry[] directoryEntries(ref TFSNode node) {
		return null;
	}

	FSNode* findNode(ref TFSNode node, string path) {
		return null;
	}

	string getName(ref TFSNode node, ref FSNode parent) {
		return null;
	}

	FSNode* getParent(ref TFSNode node, ref FSNode directory) {
		return null;
	}
}
