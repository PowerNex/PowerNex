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

import stl.address;
import stl.io.log;
import stl.vmm.heap;
import stl.vector;

@safe struct TarFSNode {
	FSNode base;
	alias base this;

	this(TarFSSuperNode* superNode_, FSNode.ID id_, FSNode.ID parent, TarHeader* header, PaxHeader paxHeader) {
		with (base) {
			readData = &this.readData;
			writeData = &this.writeData;
			directoryEntries = &this.directoryEntries;
			findNode = &this.findNode;
			link = &this.link;

			superNode = &superNode_.base;
			id = id_;

			type = header.typeFlag.toNodeType;
			size = paxHeader.fileSize ? paxHeader.fileSize : header.size.toNumber;
			blockCount = ulong.max;
		}
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

	ulong readData(ref ubyte[] buffer, ulong offset) {
		import stl.number : min;

		assert(base.type == FSNode.Type.file, "NOT A FILE!");

		size_t len = min(buffer.length, _data.length - offset);
		buffer[0 .. len] = _data[offset .. len];
		return len;
	}

	ulong writeData(const ref ubyte[] buffer, ulong offset) {
		assert(base.type == FSNode.Type.file, "NOT A FILE!");

		Log.error("TarFSNode is read-only!");
		return 0;
	}

	FSDirectoryEntry[] directoryEntries() {
		return _dirEntries[];
	}

	FSNode* findNode(string path) {
		import stl.text : indexOf;

		if (!path.length)
			return () @trusted{ return cast(FSNode*)&this; }();
		//return base.superNode.getNode(base.id);
		// return &base; // Error: returning `&this.base` escapes a reference to parameter `this`, perhaps annotate with `return`

		if (path[0] == '/')
			if (auto _ = base.superNode.getNode(0))
				return _.findNode(path[1 .. $]);
			else
				return null;

		long splitIdx = path.indexOf('/');
		if (splitIdx == -1)
			splitIdx = path.length;

		auto toFind = path[0 .. splitIdx];
		if (splitIdx == path.length)
			splitIdx--;

		size_t discardCount = splitIdx + 1;
		while (discardCount < path.length && path[discardCount] == '/')
			discardCount++;
		path = path[discardCount .. $];

		final switch (base.type) {
		case FSNode.Type.directory:
			FSNode* dir;
			foreach (const ref FSDirectoryEntry de; base.directoryEntries())
				if (de.nameStr == toFind)
					dir = base.superNode.getNode(de.id);

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
			Log.error("fineNode on type: ", base.type, " is not valid / implemented!");
			break;
		}
		return null;
	}

	void link(string name, FSNode.ID id) {
		import stl.number : min;

		assert(base.type == FSNode.Type.directory);

		FSDirectoryEntry de;
		de.id = id;
		auto len = min(name.length, de.name.length);
		de.name[0 .. len] = name[0 .. len];

		_dirEntries.put(de);
	}

	@property const(ubyte)[] data() {
		return _data;
	}

private:
	TarHeader* _header;
	PaxHeader _paxHeader;

	const(ubyte)[] _data;
	Vector!FSDirectoryEntry _dirEntries;
}
