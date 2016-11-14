module IO.FS.Initrd.FSRoot;

import IO.FS.Initrd;
import IO.FS;
import IO.Log;

import Data.Address;
import Data.String;

class InitrdFSRoot : FSRoot {
public:
	this(VirtAddress initrdAddr) {
		auto root = new DirectoryNode(NodePermissions.DefaultPermissions);
		root.Name = "Initrd";
		root.ID = idCounter++;
		super(root);

		initrd = cast(Initrd*)initrdAddr.Ptr;
		if (initrd.Magic != MAGIC)
			return;
		initrdEntries = (initrdAddr + Initrd.sizeof).Ptr!InitrdEntry[0 .. initrd.Count];
		makeNodes();
	}

	@property InitrdEntry[] InitrdEntries() {
		return initrdEntries;
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

	void makeNodes() {
		ulong[] lookup;
		lookup.length = initrdEntries.length;
		foreach (idx, entry; initrdEntries) {
			ubyte* offset = (VirtAddress(initrd) + entry.offset).Ptr!ubyte;

			auto parent = entry.parent == ulong.max ? root : cast(DirectoryNode)GetNode(lookup[entry.parent]);

			Node node;
			if (entry.type == Type.File)
				node = new InitrdFileNode(offset, entry.size);
			else if (entry.type == Type.Folder)
				node = new DirectoryNode(NodePermissions.DefaultPermissions);
			else {
				log.Error("Unknown file type! ", entry.type);
				continue;
			}

			node.Name = entry.name.fromStringz().dup;
			node.Root = this;
			node.Parent = parent;
			lookup[idx] = node.ID;
		}
		lookup.destroy;
	}
}
