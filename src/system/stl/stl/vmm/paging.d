module vmm.paging;

import stl.address;

//import memory.vmm;
import stl.trait : AliasSeq;

struct VMPage {
	VirtAddress vAddr; /// Where to map the page to
	PhysAddress pAddr; /// The page to map (if it already is allocated)
	VMPageFlags flags; /// What flags the allocation should have
	size_t refCounter; /// Reference counter for shared memory between processes
}

enum VMPageFlags {
	none = 0, /// Empty flags
	present = 1, /// The map is active
	writable = 2, /// The map is writable
	user = 4, /// User mode can access it
	execute = 8 /// Disallow code from execution
}

alias HWZoneIdentifier = ushort;

/// Hardware implementation of paging
interface IHWPaging {
	@safe:
	/// Map virtual address $(PARAM page.vAddr) to physical address $(PARAM page.pAddr) with the flags $(PARAM page.flags).
	/// $(PARAM clear) specifies if the memory should be cleared.
	bool map(VMPage* page, bool clear = false);
	/// Map virtual address $(PARAM vAddr) to physical address $(PARAM pAddr) with the flags $(PARAM flags).
	/// $(PARAM clear) specifies if the memory should be cleared.
	bool map(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false);

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

	/// Information for the VMObject for a specified address
	struct VMZoneInformation {
		VirtAddress zoneStart; /// See VMObject.zoneStart
		VirtAddress zoneEnd; /// See VMObject.zoneEnd
		HWZoneIdentifier hwZoneID; /// See VMObject.hwZoneID
	}

	/// Get information about a zone where $(PARAM address) exists.
	VMZoneInformation getZoneInfo(VirtAddress address);

	// TODO: REMOVE
	VirtAddress mapSpecialAddress(PhysMemoryRange range, bool readWrite = false, bool clear = false);
	VirtAddress mapSpecialAddress(PhysAddress pAddr, size_t size, bool readWrite = false, bool clear = false);
	void unmapSpecialAddress(ref VirtAddress vAddr, size_t size);
	VirtAddress mapSpecial(PhysAddress pAddr, size_t size, VMPageFlags flags = VMPageFlags.present, bool clear = false);
}

pragma(inline, true) IHWPaging getPaging() @safe {
	return null;
}
