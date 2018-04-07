/**
 * The filesystem base
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.tarfs.node;

import fs.tarfs;

import stl.vtable;
import stl.address;
import stl.io.log;
import stl.vmm.heap;
import stl.vector;

// dfmt off
__gshared const FSNodeVTable TarFSNodeVTable = {
	readData: VTablePtr!(typeof(FSNodeVTable.readData))(&TarFSNode.readData),
	writeData: VTablePtr!(typeof(FSNodeVTable.writeData))(&TarFSNode.writeData),
	directoryEntries: VTablePtr!(typeof(FSNodeVTable.directoryEntries))(&TarFSNode.directoryEntries),
	findNode: VTablePtr!(typeof(FSNodeVTable.findNode))(&TarFSNode.findNode),
	link: VTablePtr!(typeof(FSNodeVTable.link))(&TarFSNode.link)
};
// dfmt on

@safe struct TarFSNode {
	FSNode base = &TarFSNodeVTable;
	alias base this;

	this(TarFSSuperNode* superNode, FSNode.ID id, FSNode.ID parent, TarHeader* header, PaxHeader paxHeader) {
		base.superNode = &superNode.base;
		base.id = id;

		base.type = header.typeFlag.toNodeType;
		base.size = paxHeader.fileSize ? paxHeader.fileSize : header.size.toNumber;
		base.blockCount = ulong.max;

		_header = header;
		_paxHeader = paxHeader;

		if (type == FSNode.Type.file)
			_data = (header.VirtAddress + TarHeader.HeaderSize).array!ubyte(base.size);
		else if (type == FSNode.Type.directory) {
			_dirEntries.put(FSDirectoryEntry(id, "."));
			_dirEntries.put(FSDirectoryEntry(parent, ".."));
		} else
			assert(0, "Not implemented for this node type!!!");
	}

	static private {
		ulong readData(ref TarFSNode node, ref ubyte[] buffer, ulong offset) {
			import stl.number : min;

			assert(node.base.type == FSNode.Type.file, "NOT A FILE!");

			size_t len = min(buffer.length, node._data.length - offset);
			buffer[0 .. len] = node._data[offset .. len];
			return len;
		}

		ulong writeData(ref TarFSNode node, const ref ubyte[] buffer, ulong offset) {
			assert(node.base.type == FSNode.Type.file, "NOT A FILE!");

			Log.error("TarFSNode is read-only!");
			return 0;
		}

		FSDirectoryEntry[] directoryEntries(ref TarFSNode node) {
			return node._dirEntries[];
		}

		FSNode* findNode(ref TarFSNode node, string path) {
			import stl.text : indexOf;

			long splitIdx = path.indexOf('/');
			if (splitIdx == -1)
				splitIdx = path.length;

			auto toFind = path[0 .. splitIdx];
			if (splitIdx == path.length)
				splitIdx--;
			path = path[splitIdx + 1 .. $];

			final switch (node.base.type) {
			case FSNode.Type.directory:
				FSNode* dir;
				foreach (const ref FSDirectoryEntry de; node.base.directoryEntries())
					if (de.nameStr == toFind)
						dir = node.base.superNode.getNode(de.id);

				if (!dir)
					return null;

				if (path.length)
					dir = dir.findNode(path);

				return dir;
			case FSNode.Type.file:
			case FSNode.Type.notInUse:
			case FSNode.Type.symbolicLink:
			case FSNode.Type.hardLink:
			case FSNode.Type.mountpoint:
			case FSNode.Type.unknown:
				Log.error("fineNode on type: ", node.base.type, " is not valid / implemented!");
				break;
			}
			return null;
		}

		void link(ref TarFSNode node, string name, FSNode.ID id) {
			import stl.number : min;

			assert(node.base.type == FSNode.Type.directory);

			FSDirectoryEntry de;
			de.id = id;
			auto len = min(name.length, de.name.length);
			de.name[0 .. len] = name[0 .. len];

			node._dirEntries.put(de);
		}
	}

private:
	TarHeader* _header;
	PaxHeader _paxHeader;

	ubyte[] _data;
	Vector!FSDirectoryEntry _dirEntries;
}
