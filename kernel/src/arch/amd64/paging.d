module arch.amd64.paging;

import data.address;
import memory.vmm;
import data.util;

/*
	Recursive mapping info is from http://os.phil-opp.com/modifying-page-tables.html
*/

/// Page table level
struct PTLevel(NextLevel) {
	struct TableEntry {
		private ulong _data;

		this(TableEntry other) {
			_data = other.data;
		}

		/// If the map is active
		@property bool present() { return cast(bool)((_data >> 0x0UL) & 0x1UL); }
		/// ditto
		@property void present(bool val) { _data = (_data & ~(0x1UL << 0x0UL)) | ((val & 0x1UL) << 0x0UL); }

		// If the page is R/W instead of R/O
		@property bool readWrite() { return cast(bool)((_data >> 0x1UL) & 0x1UL); }
		/// ditto
		@property void readWrite(bool val) { _data = (_data & ~(0x1UL << 0x1UL)) | ((val & 0x1UL) << 0x1UL); }

		/// If userspace can access this page
		@property bool user() { return cast(bool)((_data >> 0x2UL) & 0x1UL); }
		/// ditto
		@property void user(bool val) { _data = (_data & ~(0x1UL << 0x2UL)) | ((val & 0x1UL) << 0x2UL); }

		/// If the map should bypass the cache and write directly to memory
		@property bool writeThrough() { return cast(bool)((_data >> 0x3UL) & 0x1UL); }
		/// ditto
		@property void writeThrough(bool val) { _data = (_data & ~(0x1UL << 0x3UL)) | ((val & 0x1UL) << 0x3UL); }

		/// If the map should bypass the read cache and read directly from memory
		@property bool cacheDisable() { return cast(bool)((_data >> 0x4UL) & 0x1UL); }
		/// ditto
		@property void cacheDisable(bool val) { _data = (_data & ~(0x1UL << 0x4UL)) | ((val & 0x1UL) << 0x4UL); }

		/// Is set when page has been accessed
		@property bool accessed() { return cast(bool)((_data >> 0x5UL) & 0x1UL); }
		/// ditto
		@property void accessed(bool val) { _data = (_data & ~(0x1UL << 0x5UL)) | ((val & 0x1UL) << 0x5UL); }

		/// Is set when page has been written to
		/// NOTE: Only valid if hugeMap is 1, else this value should be zero
		@property bool dirty() { return cast(bool)((_data >> 0x6UL) & 0x1UL); }
		/// ditto
		@property void dirty(bool val) { _data = (_data & ~(0x1UL << 0x6UL)) | ((val & 0x1UL) << 0x6UL); }

		/**
			Maps bigger pages
			Note:
				PML4: Must be zero,
				PDP: Works like a Page, but maps 1GiB
				PD: Works like a Page, but maps 4MiB
				Page: Not valid function, pat overrides this property

			See_Also:
				hugeMap, pat
		*/
		@property bool hugeMap() { return cast(bool)((_data >> 0x7UL) & 0x1UL); }
		/// ditto
		@property void hugeMap(bool val) { _data = (_data & ~(0x1UL << 0x7UL)) | ((val & 0x1UL) << 0x7UL); }

		/**
			Not implemented, Will probably be used in the future

			Docs:
				http://developer.amd.com/wordpress/media/2012/10/24593_APM_v21.pdf p.199

			See_Also:
				hugeMap
		*/
		@disable @property bool pat() { return cast(bool)((_data >> 0x7UL) & 0x1UL); }
		/// ditto
		@disable @property void pat(bool val) { _data = (_data & ~(0x1UL << 0x7UL)) | ((val & 0x1UL) << 0x7UL); }

		/// Is not cleared from the cache on a PML4 switch
		@property bool global() { return cast(bool)((_data >> 0x8UL) & 0x1UL); }
		/// ditto
		@property void global(bool val) { _data = (_data & ~(0x1UL << 0x8UL)) | ((val & 0x1UL) << 0x8UL); }

		/// For future PowerNex usage
		@property ubyte osSpecific() { return cast(ubyte)((_data >> 0x9UL) & 0x7UL); }
		/// ditto
		@property void osSpecific(ubyte val) { _data = (_data & ~(0x7UL << 0x9UL)) | ((val & 0x7UL) << 0x9UL); }

		/// The address to the next level in the page tables, or the final map address
		@property ulong data() { return cast(ulong)((_data >> 0xCUL) & 0xFFFFFFFFFFUL); }
		/// ditto
		@property void data(ulong val) { _data = (_data & ~(0xFFFFFFFFFFUL << 0xCUL)) | ((val & 0xFFFFFFFFFFUL) << 0xCUL); }

		/// For future PowerNex usage
		@property ushort osSpecific2() { return cast(ushort)((_data >> 0x34UL) & 0x7FFUL); }
		/// ditto
		@property void osSpecific2(ushort val) { _data = (_data & ~(0x7FFUL << 0x34UL)) | ((val & 0x7FFUL) << 0x34UL); }

		/// Forbids execution in the map
		@property bool noExecute() { return cast(bool)((_data >> 0x3FUL) & 0x1UL); }
		/// ditto
		@property void noExecute(bool val) { _data = (_data & ~(0x1UL << 0x3FUL)) | ((val & 0x1UL) << 0x3FUL); }

		@property PhysAddress address() {
			return PhysAddress(data << 12);
		}

		@property PhysAddress address(PhysAddress addr) {
			data = addr.num >> 12;
			return addr;
		}

		static if (!is(NextLevel == Page))
			@property NextLevel* getNextLevel() {
				VirtAddress addr = address.virtual; //TODO: Recursive map
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
