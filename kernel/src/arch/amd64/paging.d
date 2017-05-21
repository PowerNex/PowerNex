module arch.amd64.paging;

import arch.paging;
import data.address;
import data.util;
import memory.vmm;

/*
	Recursive mapping info is from http://os.phil-opp.com/modifying-page-tables.html
*/

private const _pageSize = 0x1000; //TODO: Is needed?

/// Page table level
struct PTLevel(NextLevel) {
	struct TableEntry {
		private ulong _data;

		this(TableEntry other) {
			_data = other.data;
		}

		/// If the map is active
		@property bool present() {
			return cast(bool)((_data >> 0x0UL) & 0x1UL);
		}
		/// ditto
		@property void present(bool val) {
			_data = (_data & ~(0x1UL << 0x0UL)) | ((val & 0x1UL) << 0x0UL);
		}

		// If the page is R/W instead of R/O
		@property bool readWrite() {
			return cast(bool)((_data >> 0x1UL) & 0x1UL);
		}
		/// ditto
		@property void readWrite(bool val) {
			_data = (_data & ~(0x1UL << 0x1UL)) | ((val & 0x1UL) << 0x1UL);
		}

		/// If userspace can access this page
		@property bool user() {
			return cast(bool)((_data >> 0x2UL) & 0x1UL);
		}
		/// ditto
		@property void user(bool val) {
			_data = (_data & ~(0x1UL << 0x2UL)) | ((val & 0x1UL) << 0x2UL);
		}

		/// If the map should bypass the cache and write directly to memory
		@property bool writeThrough() {
			return cast(bool)((_data >> 0x3UL) & 0x1UL);
		}
		/// ditto
		@property void writeThrough(bool val) {
			_data = (_data & ~(0x1UL << 0x3UL)) | ((val & 0x1UL) << 0x3UL);
		}

		/// If the map should bypass the read cache and read directly from memory
		@property bool cacheDisable() {
			return cast(bool)((_data >> 0x4UL) & 0x1UL);
		}
		/// ditto
		@property void cacheDisable(bool val) {
			_data = (_data & ~(0x1UL << 0x4UL)) | ((val & 0x1UL) << 0x4UL);
		}

		/// Is set when page has been accessed
		@property bool accessed() {
			return cast(bool)((_data >> 0x5UL) & 0x1UL);
		}
		/// ditto
		@property void accessed(bool val) {
			_data = (_data & ~(0x1UL << 0x5UL)) | ((val & 0x1UL) << 0x5UL);
		}

		/// Is set when page has been written to
		/// NOTE: Only valid if hugeMap is 1, else this value should be zero
		@property bool dirty() {
			return cast(bool)((_data >> 0x6UL) & 0x1UL);
		}
		/// ditto
		@property void dirty(bool val) {
			_data = (_data & ~(0x1UL << 0x6UL)) | ((val & 0x1UL) << 0x6UL);
		}

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
		@property bool hugeMap() {
			return cast(bool)((_data >> 0x7UL) & 0x1UL);
		}
		/// ditto
		@property void hugeMap(bool val) {
			_data = (_data & ~(0x1UL << 0x7UL)) | ((val & 0x1UL) << 0x7UL);
		}

		/**
			Not implemented, Will probably be used in the future

			Docs:
				http://developer.amd.com/wordpress/media/2012/10/24593_APM_v21.pdf p.199

			See_Also:
				hugeMap
		*/
		@disable @property bool pat() {
			return cast(bool)((_data >> 0x7UL) & 0x1UL);
		}
		/// ditto
		@disable @property void pat(bool val) {
			_data = (_data & ~(0x1UL << 0x7UL)) | ((val & 0x1UL) << 0x7UL);
		}

		/// Is not cleared from the cache on a PML4 switch
		@property bool global() {
			return cast(bool)((_data >> 0x8UL) & 0x1UL);
		}
		/// ditto
		@property void global(bool val) {
			_data = (_data & ~(0x1UL << 0x8UL)) | ((val & 0x1UL) << 0x8UL);
		}

		/// For future PowerNex usage (3bits)
		@property ubyte osSpecific() {
			return cast(ubyte)((_data >> 0x9UL) & 0x7UL);
		}
		/// ditto
		@property void osSpecific(ubyte val) {
			_data = (_data & ~(0x7UL << 0x9UL)) | ((val & 0x7UL) << 0x9UL);
		}

		/// The address to the next level in the page tables, or the final map address
		@property ulong data() {
			return cast(ulong)((_data >> 0xCUL) & 0xFFFFFFFFFFUL);
		}
		/// ditto
		@property void data(ulong val) {
			_data = (_data & ~(0xFFFFFFFFFFUL << 0xCUL)) | ((val & 0xFFFFFFFFFFUL) << 0xCUL);
		}

		/// For future PowerNex usage (10bits)
		@property ushort osSpecific2() {
			return cast(ushort)((_data >> 0x34UL) & 0x7FFUL);
		}
		/// ditto
		@property void osSpecific2(ushort val) {
			_data = (_data & ~(0x7FFUL << 0x34UL)) | ((val & 0x7FFUL) << 0x34UL);
		}

		/// Forbids execution in the map
		@property bool noExecute() {
			return cast(bool)((_data >> 0x3FUL) & 0x1UL);
		}
		/// ditto
		@property void noExecute(bool val) {
			_data = (_data & ~(0x1UL << 0x3FUL)) | ((val & 0x1UL) << 0x3FUL);
		}

		@property PhysAddress address() {
			return PhysAddress(data << 12);
		}

		@property PhysAddress address(PhysAddress addr) {
			data = addr.num >> 12;
			return addr;
		}

		static if (!is(NextLevel == Page))
			@property NextLevel* getPageTable() {
				ushort id = cast(ushort)((VirtAddress(&this) & 0xFFF).num / ulong.sizeof);
				return (((VirtAddress(&this) & ~0xFFF) << 9) | (id << 12)).ptr!NextLevel;
			}

		void setVMFlags(VMPageFlags flags) {
			present = !!(flags & flags.present);
			readWrite = !!(flags & flags.writable);
			user = !!(flags & flags.user);
			noExecute = !(flags & flags.execute); //NOTE! Just one '!'
		}
	}

	static assert(TableEntry.sizeof == ulong.sizeof);

	TableEntry[512] entries;
	static if (!is(NextLevel == Page))
		@property NextLevel* getPageTable(ushort id) {
			assert(id < 512);
			return ((VirtAddress(&this) << 9) | (id << 12)).ptr!NextLevel;
		}
}

alias Page = PhysAddress;
alias PML1 = PTLevel!Page;
alias PML2 = PTLevel!PML1;
alias PML3 = PTLevel!PML2;
alias PML4 = PTLevel!PML3;

alias HWZone = PML3;

private VirtAddress _makeAddress(ulong pml4, ulong pml3, ulong pml2, ulong pml1) {
	return VirtAddress(((pml4 >> 8) & 0x1 ? 0xFFFFUL << 48UL : 0) + (pml4 << 39UL) + (pml3 << 30UL) + (pml2 << 21UL) + (pml1 << 12UL));
}

private PML4* getPML4() {
	const ulong fractalID = 509;
	return _makeAddress(fractalID, fractalID, fractalID, fractalID).ptr!PML4;
}

private PML3* getPML3(ushort pml4) {
	const ulong fractalID = 509;
	return _makeAddress(fractalID, fractalID, fractalID, pml4).ptr!PML3;
}

private PML2* getPML2(ushort pml4, ushort pml3) {
	const ulong fractalID = 509;
	return _makeAddress(fractalID, fractalID, pml4, pml3).ptr!PML2;
}

private PML1* getPML1(ushort pml4, ushort pml3, ushort pml2) {
	const ulong fractalID = 509;
	return _makeAddress(fractalID, pml4, pml3, pml2).ptr!PML1;
}

private PML1* getSpecial() {
	const ulong fractalID = 509;
	const ulong specialID = 510;
	return getPML1(fractalID, 0, 0);
}

private extern (C) void cpuFlushPage(ulong addr);
private extern (C) void cpuInstallCR3(PhysAddress addr);

class HWPaging : IHWPaging {
public:
	this(PhysAddress pml4Address) {
		_addr = pml4Address;
	}

	~this() {
	}

	//TODO: maybe? void removeUserspace();

	bool map(VMPage* page, bool clear = false) {
		return map(page.vAddr, page.pAddr, page.flags, clear);
	}

	bool map(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false) {
		PML1.TableEntry* entry = _getTableEntry(vAddr);
		if (!entry)
			return false;

		entry.address = pAddr ? pAddr : getNextFreePage();
		entry.setVMFlags(flags | (clear ? VMPageFlags.writable : VMPageFlags.none));
		_flush(vAddr);

		if (clear) {
			memset(vAddr.ptr, 0, _pageSize);
			entry.readWrite = !!(flags & flags.writable);
			_flush(vAddr);
		}
		return true;
	}

	/**
		* Changes a mappings properties
		* Pseudocode:
		* --------------------
		* if (pAddr)
		* 	map.pAddr = pAddr;
		* if (flags)
		* 	map.flags = flags;
		* --------------------
		*/

	bool remap(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
		if (!pAddr || !flags)
			return true;

		PML1.TableEntry* entry = _getTableEntry(vAddr);
		if (!entry)
			return false;

		if (pAddr)
			entry.address = pAddr;
		if (flags)
			entry.setVMFlags(flags);
		_flush(vAddr);
		return true;
	}

	bool unmap(VirtAddress vAddr, bool freePage = false) {
		PML1.TableEntry* entry = _getTableEntry(vAddr);
		if (!entry)
			return false;

		if (freePage) {
			import memory.frameallocator : FrameAllocator;

			FrameAllocator.free(entry.address);
		}

		entry.address = PhysAddress();
		entry.setVMFlags(VMPageFlags.none);
		_flush(vAddr);
		return true;
	}

	PhysAddress clonePage(PhysAddress page) {
		const ulong specialID = 510;
		//TODO: This probably needs fixing for the multicore update!
		enum Position : ushort {
			from = 0,
			to = 1
		}

		//TODO: Maybe check permissions if it is allowed to read `page`

		PML1.TableEntry* from = &getSpecial().entries[Position.from];
		PML1.TableEntry* to = &getSpecial().entries[Position.to];
		VirtAddress vFrom = _makeAddress(specialID, 0, 0, Position.from);
		VirtAddress vTo = _makeAddress(specialID, 0, 0, Position.to);

		from.address = page;
		from.present = true;

		to.address = getNextFreePage();
		to.readWrite = true;
		to.present = true;

		_flush(vFrom);
		_flush(vTo);

		memcpy(vTo.ptr, vFrom.ptr, _pageSize);

		from.present = false;
		to.present = false;
		_flush(vFrom);
		_flush(vTo);
		return to.address;
	}

	PhysAddress getNextFreePage() {
		import memory.frameallocator : FrameAllocator;

		return FrameAllocator.alloc();
	}

	void freePage(PhysAddress page) {
		import memory.frameallocator : FrameAllocator;

		return FrameAllocator.free(page);
	}

	void bind() {
		cpuInstallCR3(_addr);
	}

private:
	PhysAddress _addr;

	void _flush(VirtAddress vAddr) {
		cpuFlushPage(vAddr.num);
	}

	/// Will allocate PML{3,2,1} if missing
	private PML1.TableEntry* _getTableEntry(VirtAddress vAddr, bool allocateWay = true) {
		const ulong virtAddr = vAddr.num;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pml3Idx = (virtAddr >> 30) & 0x1FF;
		const ushort pml2Idx = (virtAddr >> 21) & 0x1FF;
		const ushort pml1Idx = (virtAddr >> 12) & 0x1FF;

		PML4* pml4 = getPML4();

		// This address can be unallocated, the 'if' will allocate it in that case
		PML3* pml3 = getPML3(pml4Idx);
		{
			PML4.TableEntry* pml4Entry = &pml4.entries[pml4Idx];

			if (!pml4Entry.present)
				if (allocateWay)
					_allocateTable(pml4Entry, pml3.VirtAddress); //TODO: Is it allowed to allocate a PML4 entry? Permissions!
				else
					return null;
		}

		PML2* pml2 = getPML2(pml4Idx, pml3Idx);
		{
			PML3.TableEntry* pml3Entry = &pml3.entries[pml3Idx];
			if (!pml3Entry.present)
				if (allocateWay)
					_allocateTable(pml3Entry, pml2.VirtAddress);
				else
					return null;

		}

		PML1* pml1 = getPML1(pml4Idx, pml3Idx, pml2Idx);
		{
			PML2.TableEntry* pml2Entry = &pml2.entries[pml2Idx];
			if (!pml2Entry.present)
				if (allocateWay)
					_allocateTable(pml2Entry, pml1.VirtAddress);
				else
					return null;
		}

		return &pml1.entries[pml1Idx];
	}

	/**
		Allocate a new empty page.
		Params:
			entry = The entry that should be allocated.
			vAddr = The address the entry will have in ram.
	*/
	void _allocateTable(T)(PTLevel!(T).TableEntry* entry, VirtAddress vAddr) if (!is(T == Page)) {
		entry.present = true;
		entry.address = getNextFreePage();
		entry.readWrite = true;
		_flush(vAddr);
		memset(vAddr.ptr, 0, _pageSize);
	}
}
