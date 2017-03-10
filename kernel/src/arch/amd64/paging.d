module arch.amd64.paging;

import data.address;
import memory.vmm;
import data.bitfield;

private {
	struct Page {
		private ulong _data;

		//dfmt off
		mixin(bitfield!(_data,
			"present", 1,
			"readWrite", 1,
			"user", 1,
			"writeThrough", 1,
			"cacheDisable", 1,
			"accessed", 1,
			"dirty", 1,
			"pat", 1,
			"global", 1,
			"avl", 3,
			"address", 40,
			"available", 11,
			"noExecute", 1
		));
		//dfmt on

		@property VirtAddress data() {
			return VirtAddress(address << 12);
		}

		@property void data(VirtAddress addr) {
			address = addr.num >> 12;
			return addr;
		}
	}

	/// Page table level
	struct PTLevel(nextLevel) {
		struct TablePtr {
			private ulong _data;

			this(TablePtr other) {
				_data = other.data;
			}

			//dfmt off
			mixin(bitfield!(_data,
				"present", 1,
				"readWrite", 1,
				"user", 1,
				"writeThrough", 1,
				"cacheDisable", 1,
				"accessed", 1,
				"reserved", 1,
				"map4M", 1,
				"ignored", 1,
				"avl", 3,
				"address", 40,
				"available", 11,
				"noExecute", 1
			));
			//dfmt on

			@property PhysAddress data() {
				return PhysAddress(address << 12);
			}

			@property void data(PhysAddress addr) {
				address = addr.num >> 12;
				return addr;
			}

			@property nextLevel get() {
				//TODO:
			}
		}

		TablePtr[512] page;
	}

	alias PT = PTLevel!Page;
	alias PD = PTLevel!PT;
	alias PDP = PTLevel!PD;
	alias PML4 = PTLevel!PDP;
}

private extern (C) void cpuFlushPage(ulong addr);
private extern (C) void cpuInstallCR3(PhysAddress addr);

class HWPaging : IHWPaging {
public:
	this() {

	}

	~this() {
	}

	//TODO: maybe? void removeUserspace();

	bool map(VMPage* page, bool clear = false);
	bool map(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false);

	bool remap(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags);
	bool unmap(VirtAddress vAddr);

	PhysAddress clonePage(PhysAddress page);
	PhysAddress getNextFreePage();

	void freePage(PhysAddress page);
	void bind() {
		cpuInstallCR3(pml4);
	}

private:
	PhysAddress pml4;
}
