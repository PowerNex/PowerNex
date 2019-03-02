module stl.vmm.vmm;

import stl.address;
import stl.vector;
import stl.vmm.paging;

// https://www.freebsd.org/cgi/man.cgi?query=vm_map&sektion=9&apropos=0&manpath=FreeBSD+11-current
// https://www.freebsd.org/doc/en/articles/vm-design/vm-objects.html
// https://www.freebsd.org/doc/en/articles/vm-design/fig4.png

/// Bitmap enum containing the flags for controlling what properties the map should have
@safe enum VMPageFlags {
	none = 0, /// Empty flags
	present = 1, /// The map is active
	writable = 2, /// The map is writable
	user = 4, /// User mode can access it
	execute = 8 /// Disallow code from execution
}

/// The different states that a VMObject can be in
@safe enum VMObjectState {
	unlocked = 0, /// All the properties can be change
	locked /// The object shouldn't be changed! This happens when a object gains a child.
}

@safe enum VMMappingError {
	success = 0,
	unknownError,
	outOfMemory,
	mapNotFound,
	backendMapNotFound,
	notSupportedMap,
	alreadyMapped
}

/**
	* Represents a virtual address to physical address mapping
	*
	* If pAddr is not set and it is inside a  it is a lazy allocation.
	*/
@safe struct VMPage {
	enum Type : uint {
		cowPage, // This VMPage will be able to be Copy-on-Write
		lazyAllocate, // This VMPage will be lazy allocated
		manualMappedPage, // This VMPage is used for manual memory mapping.
		free, // This VMPage is free
	}

	VirtAddress vAddr; /// Where to map the page to
	PhysAddress pAddr; /// The page to map (if it already is allocated)
	VMPageFlags flags; /// What flags the allocation should have
	uint refCounter; /// Reference counter for shared memory between processes
	Type type; // What type of VMPage this is
}

/// This represents a allocated memory zone
@safe struct VMObject {
	VMObjectState state; /// If the object is a parent of another object, aka this object can't be changed!

	Vector!(VMPage*) pages; /// All the mapped pages
	VMObject* parent; /// The parent for the object, only valid when state != VMObjectState.manual.
	size_t refCounter; /// Reference counter, for when the pages can be freed
}
