/**
 * The filesystem base
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module fs.tarfs.supernode;

import fs.tarfs;

import stl.address;
import stl.io.log;
import stl.vmm.heap;
import stl.vector;

@safe struct TarFSSuperNode {
	FSSuperNode base;
	alias base this;

	this(TarFSBlockDevice* blockDevice) {
		with (base) {
			getNode = &this.getNode;
			saveNode = &this.saveNode;
			addNode = &this.addNode;
			removeNode = &this.removeNode;
			getFreeNodeID = &this.getFreeNodeID;
			getFreeBlockID = &this.getFreeBlockID;
			setBlockUsed = &this.setBlockUsed;
			setBlockFree = &this.setBlockFree;
		}

		_blockDevice = blockDevice;

		_loadTar();
	}

	FSNode* getNode(FSNode.ID id) {
		return &_nodes[id].base;
	}

	void saveNode(const ref FSNode node) {
	}

	FSNode* addNode(ref FSNode parent, FSNode.Type type, string name) {
		return null;
	}

	bool removeNode(ref FSNode parent, FSNode.ID id) {
		return false;
	}

	FSNode.ID getFreeNodeID() {
		return 0;
	}

	FSBlockDevice.BlockID getFreeBlockID() {
		return 0;
	}

	void setBlockUsed(FSBlockDevice.BlockID id) {
	}

	void setBlockFree(FSBlockDevice.BlockID id) {
	}

private:
	TarFSBlockDevice* _blockDevice;
	FSNode.ID _idCounter;
	Vector!(TarFSNode*) _nodes;

	void _loadTar() {
		import stl.text;

		VirtMemoryRange data = _blockDevice.data;
		VirtAddress curLoc = data.start;
		bool isEnd = false;

		PaxHeader paxHeader;
		outer: while (curLoc <= data.end) {
			TarHeader* header = curLoc.ptr!TarHeader;

			// If it starts with a NULL it is probably empty aka end of the tar file
			if (header.isNull) {
				if (!isEnd) {
					isEnd = true;

					curLoc += (TarHeader.HeaderSize + 511) & ~511;
					continue outer;
				}
				// End of tar file, got two null entries
				break outer;
			}

			// Checksum needs to be valid
			if (!header.checksumValid) {
				Log.warning("Invalid tar entry header!: ", (curLoc - data.start), " invalid: ", header.checksum.toNumber);
				break;
			}

			switch (header.typeFlag) with (TarHeader.TypeFlag) {
			case paxExtendedHeader:
				// Parse the file size if not already defined by paxGlobalExtendedHeader
				if (paxHeader.fileSize)
					break;
				goto case;

			case paxGlobalExtendedHeader:
				// Parse for 'size'
				// Format: <size> <name>=<value>\n

				paxHeader = PaxHeader();

				char[] pax = (curLoc + TarHeader.HeaderSize).array!char(header.size.toNumber);
				while (pax.length) {
					char[] line = pax[0 .. pax.indexOf('\n')];

					//ptrdiff_t lineLength = line[0 .. line.indexOf(' ')].toNumber;
					//TODO: use lineLength to validate input
					ptrdiff_t space = line.indexOf(' ');

					size_t eq = line.indexOf('=');

					const char[] key = line[space + 1 .. eq];
					const char[] value = line[eq + 1 .. $];

					if (key == "size") {
						paxHeader.fileSize = value.toNumber;
						break;
					}
					//TODO: Add more parsing of more keys

					pax = pax[line.length + 1 .. $];
				}
				break;

			default:
				TarFSNode* parent = _nodes.length ? _nodes[0] : null;
				string name = header.name.fromStringz;
				if (name[$ - 1] == '/')
					name = name[0 .. $ - 1];

				size_t idx = name.indexOfLast('/');

				if (parent && idx != -1) {
					parent = () @trusted{ return cast(TarFSNode*)parent.base.findNode(name[0 .. idx]); }();
					if (!parent) {
						Log.error("Parent: ", name[0 .. idx], " not found! Dropping file!");
						break;
					}
					name = name[idx + 1 .. $];
				}

				if (!name.length)
					break;

				if (parent)
					parent.base.link(name, _idCounter);
				_nodes.put(newStruct!TarFSNode(&this, _idCounter, parent ? parent.base.id : _idCounter, header, paxHeader));

				Log.info("Adding ", name, " (", _idCounter, "; ", header.name.fromStringz, ") ", header.typeFlag.toNodeType,
						", parent is ", parent ? parent.base.id : _idCounter);
				_idCounter++;
				break;
			}

			isEnd = false;
			curLoc += (TarHeader.HeaderSize + header.size.toNumber + 511) & ~511;
		}
	}
}
