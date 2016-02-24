module IO.FS.Initrd.RootNode;

import IO.FS.Initrd;
import IO.FS;
import IO.Log;

import Data.Address;
import Data.String;

class InitrdRootNode : DirectoryNode {
public:
	this(VirtAddress initrdAddr, DirectoryNode parent = null) {
		super(0, "Initrd", NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL), parent);
		initrd = cast(Initrd*)initrdAddr.Ptr;
		if (initrd.Magic != MAGIC)
			return;
		initrdEntries = (initrdAddr + Initrd.sizeof).Ptr!InitrdEntry[0 .. initrd.Count];
		makeNodes();
	}

	override Node GetNode(ulong id) {
		if (id < childrenCount)
			return Entries[children[id]];
		return null;
	}

	override Node GetNode(string name) {
		foreach (id; Children) {
			auto entry = Entries[id];
			if (entry.Name == name)
				return entry;
		}
		return null;
	}

	@property InitrdEntry[] InitrdEntries() {
		return initrdEntries;
	}

	@property Node[] Entries() {
		return entries;
	}

private:
	enum MAGIC = ['D', 'S', 'K', '0'];
	enum Type : ulong {
		File,
		Folder
	}

	struct Initrd {
	align(1):
		char[4] Magic;
		ulong Count;
	}

	struct InitrdEntry {
	align(1):
		char[128] name;
		ulong offset;
		ulong size;
		Type type;
		ulong parent;
	}

	Initrd* initrd;
	InitrdEntry[] initrdEntries;
	Node[] entries;

	void makeNodes() {
		entries.length = initrdEntries.length;
		DirectoryNode root;
		foreach (idx, entry; initrdEntries) {
			ubyte* offset = (VirtAddress(initrd) + entry.offset).Ptr!ubyte;

			auto parent = entry.parent == ulong.max ? this : cast(DirectoryNode)entries[entry.parent];

			if (entry.type == Type.File)
				entries[idx] = new InitrdFileNode(this, idx, entry.name.fromStringz(), offset, entry.size, parent);
			else if (entry.type == Type.Folder)
				entries[idx] = new InitrdDirectoryNode(this, idx, entry.name.fromStringz(), parent);
			else {
				log.Error("Unknown file type! ", entry.type);
				continue;
			}

			parent.AddChild(idx);
		}
	}
}

final class InitrdDirectoryNode : DirectoryNode {
	this(InitrdRootNode root, ulong id, string name, DirectoryNode parent) {
		this.root = root;
		super(id, name, NodePermissions(PermissionMask(Mask.RWX, Mask.RX, Mask.RX), 0UL, 0UL), parent);
	}

	override Node GetNode(ulong id) {
		if (id < childrenCount)
			return root.Entries[children[id]];
		return null;
	}

	override Node GetNode(string name) {
		foreach (id; Children) {
			auto entry = root.Entries[id];
			if (entry.Name == name)
				return entry;
		}
		return null;
	}

private:
	InitrdRootNode root;
}
