module stl.vmm.paging;

import stl.address : VirtAddress, PhysAddress, PhysMemoryRange;
import stl.register : Registers;
public import stl.vmm.vmm;

/+ TODO: Verify Paging implementations agains this interface
/// Hardware implementation of paging
@safe interface IPaging {
	@disable this();

	/// Map virtual address $(PARAM page.vAddr) to physical address $(PARAM page.pAddr) with the flags $(PARAM page.flags).
	/// $(PARAM clear) specifies if the memory should be cleared.
	bool mapVMPage(VMPage* page, bool clear = false);
	/// Map virtual address $(PARAM vAddr) to physical address $(PARAM pAddr) with the flags $(PARAM flags).
	/// $(PARAM clear) specifies if the memory should be cleared.
	bool mapAddress(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false);

	/**
		* Changes a mappings properties
		* Pseudocode:
		* --------------------
		* if (pAddr)
		* 	map.pAddr = pAddr;
		* if (flags) // TODO: What if you want to clear the flags?
		* 	map.flags = flags;
		* --------------------
		*/
	bool remap(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags);
	/// Remove a mapping
	bool unmap(VirtAddress vAddr, bool freePage = false);

	/// Clone a physical page with all it's data
	PhysAddress clonePage(PhysAddress page);

	/// Get the next free page
	PhysAddress getNextFreePage();

	/// Free the page $(PARAM page)
	void freePage(PhysAddress page);

	/// Bind the paging
	void bind();

	/// Get information about a zone where $(PARAM address) exists.
	VMZoneInformation getZoneInfo(VirtAddress address);

}+/

VirtAddress makeAddress(ulong pml4, ulong pml3, ulong pml2, ulong pml1) @safe nothrow {
	return VirtAddress(((pml4 >> 8) & 0x1 ? 0xFFFFUL << 48UL : 0) + (pml4 << 39UL) + (pml3 << 30UL) + (pml2 << 21UL) + (pml1 << 12UL));
}

extern (C) bool validAddress(VirtAddress vAddr) @trusted;

extern (C) void onPageFault(Registers* regs) @trusted;

// TODO: somehow remove
extern (C) VirtAddress mapSpecialAddress(PhysAddress pAddr, size_t size, bool readWrite = false, bool clear = false) @trusted;
extern (C) void unmapSpecialAddress(ref VirtAddress vAddr, size_t size) @trusted;

/// Map virtual address $(PARAM vAddr) to physical address $(PARAM pAddr) with the flags $(PARAM flags).
/// $(PARAM clear) specifies if the memory should be cleared.
extern (C) bool mapAddress(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false) @trusted;

/// Remove a mapping
extern (C) bool unmap(VirtAddress vAddr, bool freePage = false) @trusted;
