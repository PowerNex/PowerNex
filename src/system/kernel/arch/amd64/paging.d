module arch.amd64.paging;

import stl.vmm.paging;

import arch.paging;
import stl.address;
import stl.register;
import stl.trait;
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

		@property VMPageFlags vmFlags() {
			VMPageFlags flags;
			if (!present)
				return VMPageFlags.none;

			flags |= VMPageFlags.present;
			if (readWrite)
				flags |= VMPageFlags.writable;
			if (user)
				flags |= VMPageFlags.user;
			if (!noExecute) //NOTE '!'
				flags |= VMPageFlags.execute;
			return flags;
		}

		@property void vmFlags(VMPageFlags flags) {
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

/**
	* Each VMObject will be have a 4GiB zone, aka one PML3 each.
	*
	* Note:
	*  Only the lowest 9 bits will be used, because each PML4 only contains 512 entries.
	*/
alias HWZoneIdentifier = ushort;

private extern (C) void cpuFlushPage(ulong addr);
private extern (C) void cpuInstallCR3(PhysAddress addr);

VirtAddress _makeAddress(ulong pml4, ulong pml3, ulong pml2, ulong pml1) {
	return VirtAddress(((pml4 >> 8) & 0x1 ? 0xFFFFUL << 48UL : 0) + (pml4 << 39UL) + (pml3 << 30UL) + (pml2 << 21UL) + (pml1 << 12UL));
}

struct AMD64Paging {
public:
	this(PhysAddress pml4Address) {
		_addr = pml4Address;
	}

	//TODO: maybe? void removeUserspace();

	bool mapVMPage(VMPage* page, bool clear = false) {
		return mapAddress(page.vAddr, page.pAddr, page.flags, clear);
	}

	bool mapAddress(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false) {
		PML1.TableEntry* entry = _getTableEntry(vAddr);
		if (!entry)
			return false;

		if (entry.present)
			return false;

		entry.address = pAddr ? pAddr : getNextFreePage();
		entry.vmFlags(flags | (clear ? VMPageFlags.writable : VMPageFlags.none));
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

		if (!entry.present)
			return false;

		if (pAddr)
			entry.address = pAddr;
		if (flags)
			entry.vmFlags(flags);
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
		entry.vmFlags(VMPageFlags.none);
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

		PML1.TableEntry* from = &_getSpecial().entries[Position.from];
		PML1.TableEntry* to = &_getSpecial().entries[Position.to];
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

	/// Get information about a zone where $(PARAM address) exists.
	VMZoneInformation getZoneInfo(VirtAddress address) {
		const HWZoneIdentifier hwZoneID = (address.num >> 39) & 0x1FF; // Aka pml4Idx
		const VirtAddress zoneStart = _makeAddress(hwZoneID, 0, 0, 0);
		const VirtAddress zoneEnd = _makeAddress(hwZoneID + 1, 0, 0, 0) - 1;

		return VMZoneInformation(zoneStart, zoneEnd, hwZoneID);
	}

private:
	PhysAddress _addr;

	void _flush(VirtAddress vAddr) {
		cpuFlushPage(vAddr.num);
	}

	PML4* _getPML4() {
		const ulong fractalID = 509;
		return _makeAddress(fractalID, fractalID, fractalID, fractalID).ptr!PML4;
	}

	PML3* _getPML3(ushort pml4) {
		const ulong fractalID = 509;
		return _makeAddress(fractalID, fractalID, fractalID, pml4).ptr!PML3;
	}

	PML2* _getPML2(ushort pml4, ushort pml3) {
		const ulong fractalID = 509;
		return _makeAddress(fractalID, fractalID, pml4, pml3).ptr!PML2;
	}

	PML1* _getPML1(ushort pml4, ushort pml3, ushort pml2) {
		const ulong fractalID = 509;
		return _makeAddress(fractalID, pml4, pml3, pml2).ptr!PML1;
	}

	PML1* _getSpecial() {
		const ulong specialID = 510;
		return _getPML1(specialID, 0, 0);
	}

	/// Will allocate PML{3,2,1} if missing
	PML1.TableEntry* _getTableEntry(VirtAddress vAddr, bool allocateWay = true) {
		const ulong virtAddr = vAddr.num;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pml3Idx = (virtAddr >> 30) & 0x1FF;
		const ushort pml2Idx = (virtAddr >> 21) & 0x1FF;
		const ushort pml1Idx = (virtAddr >> 12) & 0x1FF;

		PML4* pml4 = _getPML4();

		// This address can be unallocated, the 'if' will allocate it in that case
		PML3* pml3 = _getPML3(pml4Idx);
		{
			PML4.TableEntry* pml4Entry = &pml4.entries[pml4Idx];

			if (!pml4Entry.present)
				if (allocateWay)
					_allocateTable(pml4Entry, pml3.VirtAddress); //TODO: Is it allowed to allocate a PML4 entry? Permissions!
				else
					return null;
		}

		PML2* pml2 = _getPML2(pml4Idx, pml3Idx);
		{
			PML3.TableEntry* pml3Entry = &pml3.entries[pml3Idx];
			if (!pml3Entry.present)
				if (allocateWay)
					_allocateTable(pml3Entry, pml2.VirtAddress);
				else
					return null;

		}

		PML1* pml1 = _getPML1(pml4Idx, pml3Idx, pml2Idx);
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

private extern (C) ulong cpuRetCR3();

extern (C) void onPageFault(Registers* regs) {
	import data.textbuffer : scr = getBootTTY;
	import io.log;

	AMD64Paging paging = AMD64Paging(cpuRetCR3);

	with (regs) {
		import data.color;

		auto addr = cr2;

		const ulong virtAddr = addr.num;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pml3Idx = (virtAddr >> 30) & 0x1FF;
		const ushort pml2Idx = (virtAddr >> 21) & 0x1FF;
		const ushort pml1Idx = (virtAddr >> 12) & 0x1FF;

		PML4.TableEntry* pml4Entry;
		PML3* pml3;

		PML3.TableEntry* pml3Entry;
		PML2* pml2;

		PML2.TableEntry* pml2Entry;
		PML1* pml1;

		PML1.TableEntry* pml1Entry;

		PML4* pml4 = paging._getPML4();
		{
			pml4Entry = &pml4.entries[pml4Idx];
			if (!pml4Entry.present)
				goto tableEntriesDone;
			pml3 = paging._getPML3(pml4Idx);
		}

		{
			pml3Entry = &pml3.entries[pml3Idx];
			if (!pml3Entry.present)
				goto tableEntriesDone;
			pml2 = paging._getPML2(pml4Idx, pml3Idx);
		}

		{
			pml2Entry = &pml2.entries[pml2Idx];
			if (!pml2Entry.present)
				goto tableEntriesDone;
			pml1 = paging._getPML1(pml4Idx, pml3Idx, pml2Idx);
		}

		{
			pml1Entry = &pml1.entries[pml1Idx];
			if (!pml1Entry.present)
				goto tableEntriesDone;
		}

	tableEntriesDone:
		VMPageFlags pml3Flags;
		VMPageFlags pml2Flags;
		VMPageFlags pml1Flags;
		VMPageFlags pageFlags;

		if (!pml4Entry)
			goto flagsDone;
		pml3Flags = pml4Entry.vmFlags;

		if (!pml3Entry)
			goto flagsDone;
		pml2Flags = pml3Entry.vmFlags;

		if (!pml2Entry)
			goto flagsDone;
		pml1Flags = pml2Entry.vmFlags;

		if (!pml1Entry)
			goto flagsDone;
		pageFlags = pml1Entry.vmFlags;

	flagsDone:
		ulong cr3 = cpuRetCR3();

		scr.foreground = Color(255, 0, 0);
		scr.writeln("===> PAGE FAULT");
		scr.writeln("IRQ = ", intNumber, " | RIP = ", rip);
		scr.writeln("RAX = ", rax, " | RBX = ", rbx);
		scr.writeln("RCX = ", rcx, " | RDX = ", rdx);
		scr.writeln("RDI = ", rdi, " | RSI = ", rsi);
		scr.writeln("RSP = ", rsp, " | RBP = ", rbp);
		scr.writeln(" R8 = ", r8, "  |  R9 = ", r9);
		scr.writeln("R10 = ", r10, " | R11 = ", r11);
		scr.writeln("R12 = ", r12, " | R13 = ", r13);
		scr.writeln("R14 = ", r14, " | R15 = ", r15);
		scr.writeln(" CS = ", cs, "  |  SS = ", ss);
		scr.writeln(" addr = ", addr, " | CR3 = ", cr3);
		scr.writeln("Flags: ", flags);
		scr.writeln("Errorcode: ", errorCode, " (", (errorCode & (1 << 0) ? " Present" : " NotPresent"), (errorCode & (1 << 1)
				? " Write" : " Read"), (errorCode & (1 << 2) ? " UserMode" : " KernelMode"), (errorCode & (1 << 3)
				? " ReservedWrite" : ""), (errorCode & (1 << 4) ? " InstructionFetch" : ""), " )");
		scr.writeln("PDP Mode: ", (pml3Flags & VMPageFlags.present) ? "R" : "", (pml3Flags & VMPageFlags.writable) ? "W" : "",
				(pml3Flags & VMPageFlags.execute) ? "X" : "", (pml3Flags & VMPageFlags.user) ? "-User" : "");
		scr.writeln("PD Mode: ", (pml2Flags & VMPageFlags.present) ? "R" : "", (pml2Flags & VMPageFlags.writable) ? "W" : "",
				(pml2Flags & VMPageFlags.execute) ? "X" : "", (pml2Flags & VMPageFlags.user) ? "-User" : "");
		scr.writeln("PT Mode: ", (pml1Flags & VMPageFlags.present) ? "R" : "", (pml1Flags & VMPageFlags.writable) ? "W" : "",
				(pml1Flags & VMPageFlags.execute) ? "X" : "", (pml1Flags & VMPageFlags.user) ? "-User" : "");
		scr.writeln("Page Mode: ", (pageFlags & VMPageFlags.present) ? "R" : "", (pageFlags & VMPageFlags.writable) ? "W" : "",
				(pageFlags & VMPageFlags.execute) ? "X" : "", (pageFlags & VMPageFlags.user) ? "-User" : "");

		//dfmt off
		Log.fatal("===> PAGE FAULT", "\n", "IRQ = ", intNumber, " | RIP = ", rip, "\n",
			"RAX = ", rax, " | RBX = ", rbx, "\n",
			"RCX = ", rcx, " | RDX = ", rdx, "\n",
			"RDI = ", rdi, " | RSI = ", rsi, "\n",
			"RSP = ", rsp, " | RBP = ", rbp, "\n",
			" R8 = ", r8, "  |  R9 = ", r9, "\n",
			"R10 = ", r10, " | R11 = ", r11, "\n",
			"R12 = ", r12, " | R13 = ", r13, "\n",
			"R14 = ", r14, " | R15 = ", r15, "\n",
			" CS = ", cs, "  |  SS = ", ss, "\n",
			" addr = ",	addr, " | CR3 = ", cr3, "\n",
			"Flags: ", flags, "\n",
			"Errorcode: ", errorCode, " (",
				(errorCode & (1 << 0) ? " Present" : " NotPresent"),
				(errorCode & (1 << 1) ? " Write" : " Read"),
				(errorCode & (1 << 2) ? " UserMode" : " KernelMode"),
				(errorCode & (1 << 3) ? " ReservedWrite" : ""),
				(errorCode & (1 << 4) ? " InstructionFetch" : ""),
			" )", "\n",
			"PDP Mode: ",
				(pml3Flags & VMPageFlags.present) ? "R" : "",
				(pml3Flags & VMPageFlags.writable) ? "W" : "",
				(pml3Flags & VMPageFlags.execute) ? "X" : "",
				(pml3Flags & VMPageFlags.user) ? "-User" : "", "\n",
			"PD Mode: ",
				(pml2Flags & VMPageFlags.present) ? "R" : "",
				(pml2Flags & VMPageFlags.writable) ? "W" : "",
				(pml2Flags & VMPageFlags.execute) ? "X" : "",
				(pml2Flags & VMPageFlags.user) ? "-User" : "", "\n",
			"PT Mode: ",
				(pml1Flags & VMPageFlags.present) ? "R" : "",
				(pml1Flags & VMPageFlags.writable) ? "W" : "",
				(pml1Flags & VMPageFlags.execute) ? "X" : "",
				(pml1Flags & VMPageFlags.user) ? "-User" : "", "\n",
			"Page Mode: ",
				(pageFlags & VMPageFlags.present) ? "R" : "",
				(pageFlags & VMPageFlags.writable) ? "W" : "",
				(pageFlags & VMPageFlags.execute) ? "X" : "",
				(pageFlags & VMPageFlags.user) ? "-User" : "");
		//dfmt on
	}
}
