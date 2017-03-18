module arch.amd64.paging;

import data.address;
import memory.vmm;
import data.bitfield;
import data.util;

/// Page table level
struct PTLevel(NextLevel) {
	struct TableEntry {

		private enum _isPage = is(NextLevel == PhysAddress);

		private ulong _data;

		this(TableEntry other) {
			_data = other.data;
		}

		static if (_isPage)
			alias specialOptions = TypeTuple!("dirty", 1, "pat", 1, "global", 1);
		else
			alias specialOptions = TypeTuple!("reserved", 1, "map4M", 1, "ignored", 1);

		//dfmt off
			mixin(bitfield!(_data,
				"present", 1,
				"readWrite", 1,
				"user", 1,
				"writeThrough", 1,
				"cacheDisable", 1,
				"accessed", 1,
				specialOptions,
				"avl", 3,
				"address", 40,
				"available", 11,
				"noExecute", 1
			));
			//dfmt on

		@property PhysAddress data() {
			return PhysAddress(address << 12);
		}

		@property PhysAddress data(PhysAddress addr) {
			address = addr.num >> 12;
			return addr;
		}

		static if (_isPage)
			alias get = data;
		else
			@property NextLevel* get() {
				VirtAddress addr = data().virtual; //TODO: Recursive map
				return addr.ptr!NextLevel;
			}
	}

	TableEntry[512] entries;
}

alias Page = PhysAddress;
alias PT = PTLevel!Page;
alias PD = PTLevel!PT;
alias PDP = PTLevel!PD;
alias PML4 = PTLevel!PDP;

private extern (C) void cpuFlushPage(ulong addr);
private extern (C) void cpuInstallCR3(PhysAddress addr);

class HWPaging : IHWPaging {
public:
	this() {

	}

	~this() {
	}

	//TODO: maybe? void removeUserspace();

	bool map(VMPage* page, bool clear = false) {
		assert(0);
	}

	bool map(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false) {
		assert(0);
	}

	bool remap(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
		assert(0);
	}

	bool unmap(VirtAddress vAddr) {
		assert(0);
	}

	PhysAddress clonePage(PhysAddress page) {
		assert(0);
	}

	PhysAddress getNextFreePage() {
		assert(0);
	}

	void freePage(PhysAddress page) {
		assert(0);
	}

	void bind() {
		cpuInstallCR3(addr);
	}

private:
	PhysAddress addr;
	PML4* pml4;
}
