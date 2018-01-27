/**
 * A module for interfacing with the $(I Memory Manager).
 * Here we can map and unmap virtual pages to physical pages.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module arch.amd64.paging;

import stl.address;

/*
	Recursive mapping info is from http://os.phil-opp.com/modifying-page-tables.html
*/

private const _pageSize = 0x1000; //TODO: Is needed?

/// Bitmap enum containing the flags for controlling what properties the map should have
enum PageFlags {
	none = 0, /// Empty flags
	present = 1, /// The map is active
	writable = 2, /// The map is writable
	user = 4, /// User mode can access it
	execute = 8 /// Allow code from execution
}

/// Page table level
@safe struct PTLevel(NextLevel) {
	@safe struct TableEntry {
		private ulong _data;

		this(TableEntry other) {
			_data = other.data;
		}

		/// If the map is active
		@property bool present() const {
			return cast(bool)((_data >> 0x0UL) & 0x1UL);
		}
		/// ditto
		@property void present(bool val) {
			_data = (_data & ~(0x1UL << 0x0UL)) | ((val & 0x1UL) << 0x0UL);
		}

		// If the page is R/W instead of R/O
		@property bool readWrite() const {
			return cast(bool)((_data >> 0x1UL) & 0x1UL);
		}
		/// ditto
		@property void readWrite(bool val) {
			_data = (_data & ~(0x1UL << 0x1UL)) | ((val & 0x1UL) << 0x1UL);
		}

		/// If userspace can access this page
		@property bool user() const {
			return cast(bool)((_data >> 0x2UL) & 0x1UL);
		}
		/// ditto
		@property void user(bool val) {
			_data = (_data & ~(0x1UL << 0x2UL)) | ((val & 0x1UL) << 0x2UL);
		}

		/// If the map should bypass the cache and write directly to memory
		@property bool writeThrough() const {
			return cast(bool)((_data >> 0x3UL) & 0x1UL);
		}
		/// ditto
		@property void writeThrough(bool val) {
			_data = (_data & ~(0x1UL << 0x3UL)) | ((val & 0x1UL) << 0x3UL);
		}

		/// If the map should bypass the read cache and read directly from memory
		@property bool cacheDisable() const {
			return cast(bool)((_data >> 0x4UL) & 0x1UL);
		}
		/// ditto
		@property void cacheDisable(bool val) {
			_data = (_data & ~(0x1UL << 0x4UL)) | ((val & 0x1UL) << 0x4UL);
		}

		/// Is set when page has been accessed
		@property bool accessed() const {
			return cast(bool)((_data >> 0x5UL) & 0x1UL);
		}
		/// ditto
		@property void accessed(bool val) {
			_data = (_data & ~(0x1UL << 0x5UL)) | ((val & 0x1UL) << 0x5UL);
		}

		/// Is set when page has been written to
		/// NOTE: Only valid if hugeMap is 1, else this value should be zero
		@property bool dirty() const {
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
		@property bool hugeMap() const {
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
		@disable @property bool pat() const {
			return cast(bool)((_data >> 0x7UL) & 0x1UL);
		}
		/// ditto
		@disable @property void pat(bool val) {
			_data = (_data & ~(0x1UL << 0x7UL)) | ((val & 0x1UL) << 0x7UL);
		}

		/// Is not cleared from the cache on a PML4 switch
		@property bool global() const {
			return cast(bool)((_data >> 0x8UL) & 0x1UL);
		}
		/// ditto
		@property void global(bool val) {
			_data = (_data & ~(0x1UL << 0x8UL)) | ((val & 0x1UL) << 0x8UL);
		}

		/// For future PowerNex usage (3bits)
		@property ubyte osSpecific() const {
			return cast(ubyte)((_data >> 0x9UL) & 0x7UL);
		}
		/// ditto
		@property void osSpecific(ubyte val) {
			_data = (_data & ~(0x7UL << 0x9UL)) | ((val & 0x7UL) << 0x9UL);
		}

		/// The address to the next level in the page tables, or the final map address
		@property ulong data() const {
			return cast(ulong)((_data >> 0xCUL) & 0xFFFFFFFFFFUL);
		}
		/// ditto
		@property void data(ulong val) {
			_data = (_data & ~(0xFFFFFFFFFFUL << 0xCUL)) | ((val & 0xFFFFFFFFFFUL) << 0xCUL);
		}

		/// For future PowerNex usage (10bits)
		@property ushort osSpecific2() const {
			return cast(ushort)((_data >> 0x34UL) & 0x7FFUL);
		}
		/// ditto
		@property void osSpecific2(ushort val) {
			_data = (_data & ~(0x7FFUL << 0x34UL)) | ((val & 0x7FFUL) << 0x34UL);
		}

		/// Forbids execution in the map
		@property bool noExecute() const {
			return cast(bool)((_data >> 0x3FUL) & 0x1UL);
		}
		/// ditto
		@property void noExecute(bool val) {
			_data = (_data & ~(0x1UL << 0x3FUL)) | ((val & 0x1UL) << 0x3FUL);
		}

		@property PhysAddress address() const {
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

		@property PageFlags vmFlags() const {
			PageFlags flags;
			if (!present)
				return PageFlags.none;

			flags |= PageFlags.present;
			if (readWrite)
				flags |= PageFlags.writable;
			if (user)
				flags |= PageFlags.user;
			if (!noExecute) //NOTE '!'
				flags |= PageFlags.execute;
			return flags;
		}

		@property void vmFlags(PageFlags flags) {
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

private extern (C) void cpuFlushPage(ulong addr) @safe; // XXX: Remove @safe?
private extern (C) extern PhysAddress pml4; // XXX: Is in reality a VirtAddress

VirtAddress _makeAddress(ulong pml4, ulong pml3, ulong pml2, ulong pml1) @safe {
	return VirtAddress(((pml4 >> 8) & 0x1 ? 0xFFFFUL << 48UL : 0) + (pml4 << 39UL) + (pml3 << 30UL) + (pml2 << 21UL) + (pml1 << 12UL));
}

@safe static struct Paging {
public static:
	void init() {
		import arch.amd64.idt : IDT, InterruptType;

		IDT.register(InterruptType.pageFault, &_onPageFault);
	}

	//TODO: maybe? void removeUserspace();

	///
	VirtAddress mapSpecialAddress(PhysMemoryRange range, bool readWrite = false, bool clear = false) {
		return mapSpecialAddress(range.start, range.size, readWrite, clear);
	}

	///
	VirtAddress mapSpecialAddress(PhysAddress pAddr, size_t size, bool readWrite = false, bool clear = false) {
		import arch.amd64.paging : Paging, PageFlags;

		const PhysAddress pa = pAddr & ~0xFFF;
		const size_t offset = pAddr.num & 0xFFF;

		return Paging.mapSpecial(pa, size + offset, PageFlags.present | (readWrite ? PageFlags.writable : PageFlags.none), clear) + offset;
	}

	///
	void unmapSpecialAddress(ref VirtAddress vAddr, size_t size) {
		import arch.amd64.paging : Paging;

		long offset = vAddr.num & 0xFFF;
		size += offset;

		VirtAddress tmp = vAddr & ~0xFFF;
		while (offset > 0) {
			Paging.unmap(tmp, false);
			tmp += 0x1000;
			offset -= 0x1000;
		}
		vAddr.addr = 0;
	}

	VirtAddress mapSpecial(PhysAddress pAddr, size_t size, PageFlags flags = PageFlags.present, bool clear = false) {
		import io.log : Log;

		const size_t pagesNeeded = ((size + 0xFFF) & ~0xFFF) / 0x1000;

		const ulong specialID = 510; // XXX: Find this from somewhere else
		PML1* special = _getSpecial();

		size_t freePage = size_t.max;
		size_t amountFree;
		foreach (idx, const ref PML1.TableEntry entry; special.entries) {
			if (!entry.present) {
				if (!amountFree)
					freePage = idx;
				amountFree++;
				if (pagesNeeded == amountFree)
					break;
			} else
				amountFree = 0;
		}

		if (freePage == size_t.max || pagesNeeded != amountFree)
			Log.fatal("Special PML1 is full!");

		VirtAddress vAddr = _makeAddress(specialID, 0, 0, freePage);
		Log.info("Mapping [", vAddr, " - ", vAddr + pagesNeeded * 0x1000 - 1, "]");
		foreach (i; 0 .. pagesNeeded) {
			PML1.TableEntry* entry = &special.entries[freePage + i];

			entry.address = pAddr + i * 0x1000;
			entry.vmFlags = flags | (clear ? PageFlags.writable : PageFlags.none);
			_flush(vAddr);

			if (clear) {
				vAddr.memset(0, _pageSize);
				entry.readWrite = !!(flags & flags.writable);
				_flush(vAddr);
			}
		}
		return vAddr;
	}

	bool map(VirtAddress vAddr, PhysAddress pAddr, PageFlags flags = PageFlags.present, bool clear = false) {
		import io.log : Log;

		PML1.TableEntry* entry = _getTableEntry(vAddr);
		if (!entry) {
			Log.fatal("Entry does not exist!");
			return false;
		}

		if (entry.present) {
			Log.fatal("Entry is already mapped to: ", entry.address);
			return false;
		}

		entry.address = pAddr ? pAddr : getNextFreePage();
		entry.vmFlags = flags | (clear ? PageFlags.writable : PageFlags.none);
		_flush(vAddr);

		if (clear) {
			vAddr.memset(0, _pageSize);
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

	bool remap(VirtAddress vAddr, PhysAddress pAddr, PageFlags flags) {
		PML1.TableEntry* entry = _getTableEntry(vAddr);
		if (!entry)
			return false;

		if (!entry.present)
			return false;

		if (!!pAddr)
			entry.address = pAddr;
		if (!!flags)
			entry.vmFlags = flags;
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
		entry.vmFlags = PageFlags.none;
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

		vTo.memcpy(vFrom, _pageSize);

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

private static:
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
		vAddr.memset(0, _pageSize);
	}
}

private void _onPageFault(from!"stl.register".Registers* regs) @safe {
	import io.vga : VGA, CGAColor, CGASlotColor;
	import io.log : Log;
	import stl.text : HexInt;
	import arch.amd64.lapic : LAPIC;

	size_t id = LAPIC.getCurrentID();

	with (regs) {
		const ulong virtAddr = cr2.num;
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

		PML4* pml4 = Paging._getPML4();
		{
			pml4Entry = &pml4.entries[pml4Idx];
			if (!pml4Entry.present)
				goto tableEntriesDone;
			pml3 = Paging._getPML3(pml4Idx);
		}

		{
			pml3Entry = &pml3.entries[pml3Idx];
			if (!pml3Entry.present)
				goto tableEntriesDone;
			pml2 = Paging._getPML2(pml4Idx, pml3Idx);
		}

		{
			pml2Entry = &pml2.entries[pml2Idx];
			if (!pml2Entry.present)
				goto tableEntriesDone;
			pml1 = Paging._getPML1(pml4Idx, pml3Idx, pml2Idx);
		}

		{
			pml1Entry = &pml1.entries[pml1Idx];
			if (!pml1Entry.present)
				goto tableEntriesDone;
		}

	tableEntriesDone:
		PageFlags pml3Flags;
		PageFlags pml2Flags;
		PageFlags pml1Flags;
		PageFlags pageFlags;

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
		Log.Func func = Log.getFuncName(rip);

		VGA.color = CGASlotColor(CGAColor.red, CGAColor.black);
		VGA.writeln("===> PAGE FAULT (CPU ", id, ")");
		VGA.writeln("                          | RIP = ", rip);
		VGA.writeln("RAX = ", rax, " | RBX = ", rbx);
		VGA.writeln("RCX = ", rcx, " | RDX = ", rdx);
		VGA.writeln("RDI = ", rdi, " | RSI = ", rsi);
		VGA.writeln("RSP = ", rsp, " | RBP = ", rbp);
		VGA.writeln(" R8 = ", r8, " |  R9 = ", r9);
		VGA.writeln("R10 = ", r10, " | R11 = ", r11);
		VGA.writeln("R12 = ", r12, " | R13 = ", r13);
		VGA.writeln("R14 = ", r14, " | R15 = ", r15);
		VGA.writeln(" CS = ", cs, " |  SS = ", ss);
		VGA.writeln("CR0 = ", cr0, " | CR2 = ", cr2);
		VGA.writeln("CR3 = ", cr3, " | CR4 = ", cr4);
		VGA.writeln("Flags = ", flags.num.HexInt);
		VGA.writeln("Errorcode: ", errorCode.num.HexInt, " (", (errorCode & (1 << 0) ? " Present" : " NotPresent"),
				(errorCode & (1 << 1) ? " Write" : " Read"), (errorCode & (1 << 2) ? " UserMode" : " KernelMode"),
				(errorCode & (1 << 3) ? " ReservedWrite" : ""), (errorCode & (1 << 4) ? " InstructionFetch" : ""), " )");
		VGA.writeln("PDP Mode: ", (pml3Flags & PageFlags.present) ? "R" : "", (pml3Flags & PageFlags.writable) ? "W" : "",
				(pml3Flags & PageFlags.execute) ? "X" : "", (pml3Flags & PageFlags.user) ? "-User" : "");
		VGA.writeln("PD Mode: ", (pml2Flags & PageFlags.present) ? "R" : "", (pml2Flags & PageFlags.writable) ? "W" : "",
				(pml2Flags & PageFlags.execute) ? "X" : "", (pml2Flags & PageFlags.user) ? "-User" : "");
		VGA.writeln("PT Mode: ", (pml1Flags & PageFlags.present) ? "R" : "", (pml1Flags & PageFlags.writable) ? "W" : "",
				(pml1Flags & PageFlags.execute) ? "X" : "", (pml1Flags & PageFlags.user) ? "-User" : "");
		VGA.writeln("Page Mode: ", (pageFlags & PageFlags.present) ? "R" : "", (pageFlags & PageFlags.writable) ? "W" : "",
				(pageFlags & PageFlags.execute) ? "X" : "", (pageFlags & PageFlags.user) ? "-User" : "");
		//dfmt off
		Log.fatal("===> PAGE FAULT (CPU ", id, ")", "\n",
			"                          | RIP = ", rip, " (", func.name, '+', func.diff.HexInt, ')', "\n",
			"RAX = ", rax, " | RBX = ", rbx, "\n",
			"RCX = ", rcx, " | RDX = ", rdx, "\n",
			"RDI = ", rdi, " | RSI = ", rsi, "\n",
			"RSP = ", rsp, " | RBP = ", rbp, "\n",
			" R8 = ", r8,  " |  R9 = ", r9, "\n",
			"R10 = ", r10, " | R11 = ", r11, "\n",
			"R12 = ", r12, " | R13 = ", r13, "\n",
			"R14 = ", r14, " | R15 = ", r15, "\n",
			" CS = ", cs,  " |  SS = ", ss, "\n",
			"CR0 = ",	cr0," | CR2 = ", cr2, "\n",
			"CR3 = ",	cr3, " | CR4 = ", cr4, "\n",
			"Flags = ", flags.num.HexInt, "\n",
			"Errorcode: ", errorCode.num.HexInt, " (",
				(errorCode & (1 << 0) ? " Present" : " NotPresent"),
				(errorCode & (1 << 1) ? " Write" : " Read"),
				(errorCode & (1 << 2) ? " UserMode" : " KernelMode"),
				(errorCode & (1 << 3) ? " ReservedWrite" : ""),
				(errorCode & (1 << 4) ? " InstructionFetch" : ""),
			" )", "\n",
			"PDP Mode: ",
				(pml3Flags & PageFlags.present) ? "R" : "",
				(pml3Flags & PageFlags.writable) ? "W" : "",
				(pml3Flags & PageFlags.execute) ? "X" : "",
				(pml3Flags & PageFlags.user) ? "-User" : "", "\n",
			"PD Mode: ",
				(pml2Flags & PageFlags.present) ? "R" : "",
				(pml2Flags & PageFlags.writable) ? "W" : "",
				(pml2Flags & PageFlags.execute) ? "X" : "",
				(pml2Flags & PageFlags.user) ? "-User" : "", "\n",
			"PT Mode: ",
				(pml1Flags & PageFlags.present) ? "R" : "",
				(pml1Flags & PageFlags.writable) ? "W" : "",
				(pml1Flags & PageFlags.execute) ? "X" : "",
				(pml1Flags & PageFlags.user) ? "-User" : "", "\n",
			"Page Mode: ",
				(pageFlags & PageFlags.present) ? "R" : "",
				(pageFlags & PageFlags.writable) ? "W" : "",
				(pageFlags & PageFlags.execute) ? "X" : "",
				(pageFlags & PageFlags.user) ? "-User" : "");
		//dfmt on
	}
}
