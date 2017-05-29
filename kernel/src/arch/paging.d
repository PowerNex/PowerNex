module arch.paging;

version (X86_64) {
	public import arch.amd64.paging;
} else {
	static assert(0, "Paging is not implemented for the architecture!");
}

import data.address;
import memory.vmm;
import data.util : TypeTuple;

//TODO: Change to HWPaging, using hack to allocator class!
__gshared IHWPaging kernelHWPaging;

interface IHWPaging { // Hardware implementation of paging
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
}

void initKernelHWPaging() {
	import data.util : inplaceClass;
	import data.linker : Linker;
	import data.address : PhysAddress;

	immutable ulong KERNEL_VMA = 0xFFFFFFFF80000000; // From boot.S

	PhysAddress pml4 = PhysAddress(Linker.pml4.num - KERNEL_VMA);

	__gshared ubyte[__traits(classInstanceSize, HWPaging)] classData;
	kernelHWPaging = cast(IHWPaging)inplaceClass!HWPaging(classData, pml4);
}
