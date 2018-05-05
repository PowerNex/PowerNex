module stl.vmm.vmm;

import stl.address;
import stl.vector;
import stl.vmm.paging;

// https://www.freebsd.org/cgi/man.cgi?query=vm_map&sektion=9&apropos=0&manpath=FreeBSD+11-current
// https://www.freebsd.org/doc/en/articles/vm-design/vm-objects.html
// https://www.freebsd.org/doc/en/articles/vm-design/fig4.png

/// Bitmap enum containing the flags for controlling what properties the map should have
enum VMPageFlags {
	none = 0, /// Empty flags
	present = 1, /// The map is active
	writable = 2, /// The map is writable
	user = 4, /// User mode can access it
	execute = 8 /// Disallow code from execution
}

/// The different states that a VMObject can be in
enum VMObjectState {
	unlocked = 0, /// All the properties can be change
	locked, /// The object shouldn't be changed! This happens when a object gains a child.
	manual /// This object is used for manual memory mapping. Can't gain a child or be CoW'd. Fork will make a copy of it.
}

enum VMMappingError {
	success,
	unknownError,
	outOfMemory,
	noMemoryZoneAllocated,
	mapNotFound,
	notSupportedMap,
	alreadyMapped
}

/**
	* Represents a virtual address to physical address mapping
	*
	* If pAddr is not set it is a lazy allocation.
	*/
struct VMPage {
	VirtAddress vAddr; /// Where to map the page to
	PhysAddress pAddr; /// The page to map (if it already is allocated)
	VMPageFlags flags; /// What flags the allocation should have
	size_t refCounter; /// Reference counter for shared memory between processes
}

///
@safe alias HWZoneIdentifier = ushort;

/// This represents a allocated memory region
struct VMObject {
	VMObjectState state; /// If the object is a parent of another object, aka this object can't be changed!

	//TODO: Be able to make a inlockable object for storeing map(vAddr, pAddr) maps. Maps that should never be CoW
	// or have a parent

	VirtAddress zoneStart; /// The start of the memory zone that this object controls
	VirtAddress zoneEnd; /// The end of the memory zone that this object controls
	HWZoneIdentifier hwZoneID; /// The identification the HWPaging used to identify this zone

	Vector!(VMPage*) pages; /// All the mapped pages
	VMObject* parent; /// The parent for the object
	size_t refCounter; /// Reference counter, for when the pages can be freed
}

/// Information for the VMObject for a specified address
struct VMZoneInformation {
	VirtAddress zoneStart; /// See VMObject.zoneStart
	VirtAddress zoneEnd; /// See VMObject.zoneEnd
	HWZoneIdentifier hwZoneID; /// See VMObject.hwZoneID
}
