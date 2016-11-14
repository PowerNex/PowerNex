module io.fs.initrd.fsroot;

import io.fs.initrd;
import io.fs;
import io.log;

import data.address;
import data.string_;

class InitrdFSRoot : FSRoot {
public:
	this(VirtAddress initrdAddr) {
		auto root = new DirectoryNode(NodePermissions.defaultPermissions);
		root.name = "Initrd";
		root.id = _idCounter++;
		super(root);

		_initrd = cast(Initrd*)initrdAddr.ptr;
		if (_initrd.magic != _magic)
			return;
		_initrdEntries = (initrdAddr + Initrd.sizeof).ptr!InitrdEntry[0 .. _initrd.count];
		makeNodes();
	}

	@property InitrdEntry[] initrdEntries() {
		return _initrdEntries;
	}

private:
	enum _magic = ['D', 'S', 'K', '0'];
	enum Type : ulong {
		file,
		folder
	}

	struct Initrd {
	align(1):
		char[4] magic;
		ulong count;
	}

	struct InitrdEntry {
	align(1):
		char[128] name;
		ulong offset;
		ulong size;
		Type type;
		ulong parent;
	}

	Initrd* _initrd;
	InitrdEntry[] _initrdEntries;

	void makeNodes() {
		ulong[] lookup;
		lookup.length = _initrdEntries.length;
		foreach (idx, entry; _initrdEntries) {
			ubyte* offset = (VirtAddress(_initrd) + entry.offset).ptr!ubyte;

			auto parent = entry.parent == ulong.max ? root : cast(DirectoryNode)getNode(lookup[entry.parent]);

			Node node;
			if (entry.type == Type.file)
				node = new InitrdFileNode(offset, entry.size);
			else if (entry.type == Type.folder)
				node = new DirectoryNode(NodePermissions.defaultPermissions);
			else {
				log.error("Unknown file type! ", entry.type);
				continue;
			}

			node.name = entry.name.fromStringz().dup;
			node.root = this;
			node.parent = parent;
			lookup[idx] = node.id;
		}
		lookup.destroy;
	}
}
