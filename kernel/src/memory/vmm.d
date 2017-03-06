module memory.vmm;

import data.address;
import data.container;
import memory.ref_;
import memory.allocator;

// https://www.freebsd.org/cgi/man.cgi?query=vm_map&sektion=9&apropos=0&manpath=FreeBSD+11-current
// https://www.freebsd.org/doc/en/articles/vm-design/vm-objects.html
// https://www.freebsd.org/doc/en/articles/vm-design/fig4.png

/// Flags for controlling what properties the map should have
enum VMPageFlags {
	present = 1, /// The map is active
	writable = 2, /// The map is writable
	user = 4, /// User mode can access it
	//TODO: implement? somehow. somewhere
	//TODO: Change it to be positive, noExecute -> execute?
	noExecute = 8 /// Disallow code from execution
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

/// This represents a allocated memory region
struct VMObject {
	bool locked; /// If the object is a parent of another object, aka this object can't be changed!

	Vector!(VMPage*) pages; /// All the mapped pages
	VMObject* parent; /// The parent for the object
	size_t refCounter; /// Reference counter, for when the pages can be freed
}

/// This represents one or more process address spaces
struct VMProcess {
	Vector!(VMObject*) objects; /// All the object that is associated with the process
	Ref!IHWPaging backend; /// The paging backend
	// TODO: Maybe remove this refCounter, if Ref!VMProcess is used!
	size_t refCounter; /// Reference counter, for when the VMProcess is used in cloned processes
	@disable this();
	this(Ref!IHWPaging backend) {
		objects = kernelAllocator.make!(Vector!(VMObject*))(kernelAllocator);
		backend = backend;
		refCounter = 1;
	}

	~this() {
		// Don't unmap anything, it will just waste power. This VMProcess is dead when this is called.
		void freeObject(VMObject* o) {
			if (!o)
				return;
			o.refCounter--;
			if (o.refCounter)
				return;

			// Free pages
			foreach (VMPage* p; o.pages) {
				p.refCounter--;
				if (p.refCounter)
					continue;

				if (p.pAddr)
					(*backend).freePage(p.pAddr);

				kernelAllocator.dispose(p);
			}
			kernelAllocator.dispose(o.pages);

			// Free parent
			freeObject(o.parent);

			kernelAllocator.dispose(o);
		}

		foreach (VMObject* o; objects)
			freeObject(o);
		kernelAllocator.dispose(objects);
	}

	PageFaultStatus onPageFault(scope Process process, VirtAddress vAddr, bool present, bool write, bool user) {
		auto backend = *this.backend;
		vAddr &= ~0xFFF;

		if (present) {
			if (!write) {
				if (user)
					process.signal(SignalType.accessDenied, "User is trying to read to kernel page");
				else
					process.signal(SignalType.kernelError, "Kernal is trying to read to kernel page");
				return PageFaultStatus.unknownError;
			} else if (user) {
				process.signal(SignalType.accessDenied, "User is trying to write to kernel page");
				return PageFaultStatus.unknownError;
			}

			//CoW
			VMObject* obj;
			VMPage* page;

			// If page is found in curObject && curObject.locked; then
			//   Allocate new object on top
			// Set obj to the object that should own the page
			// Set page to the page
			outer_1: foreach (ref VMObject* curObject; objects) {
				VMObject* o = curObject;
				if (!o.locked)
					o = o.parent;
				while (o) {
					foreach (VMPage* p; o.pages)
						if (p.vAddr == vAddr) {
							if (curObject.locked) { // Replace curObject
								VMObject* newCurrentObject = kernelAllocator.make!VMObject();
								if (!newCurrentObject) { //TODO: Cleanup
									process.signal(SignalType.noMemory, "Out of memory");
									return PageFaultStatus.unknownError;
								}
								newCurrentObject.locked = false;
								newCurrentObject.parent = curObject;
								newCurrentObject.refCounter = 1;

								curObject = newCurrentObject;
							}
							obj = curObject;
							page = p;
							break outer_1;
						}
					o = o.parent;
				}
			}

			if (!page) {
				process.signal(SignalType.corruptedMemory, "Expected CoW allocation, but could not find page");
				return PageFaultStatus.unknownError;
			}

			VMPage* newPage = kernelAllocator.make!VMPage(); // TODO: Reuse old pages
			if (!newPage) { //TODO: Cleanup
				process.signal(SignalType.noMemory, "Out of memory");
				return PageFaultStatus.unknownError;
			}
			newPage.vAddr = vAddr;
			newPage.flags = page.flags;
			newPage.pAddr = backend.clonePage(page.pAddr);
			newPage.refCounter = 1;
			backend.map(newPage);

			obj.pages.put(newPage);
		} else {
			// Lazy allocation
			VMPage* page;

			// Get the page that correspondence to the vAddr in a non-locked object
			// If it is found in a locked object, allocated a new root unlocked object and
			// allocate a vmpage in that object that will be used.
			outer_2: foreach (ref VMObject* curObject; objects) {
				VMObject* o = curObject;
				while (o) {
					foreach (VMPage* p; o.pages)
						if (p.vAddr == vAddr) {
							if (curObject.locked) { // Replace curObject
								VMObject* newCurrentObject = kernelAllocator.make!VMObject();
								if (!newCurrentObject) { //TODO: Cleanup
									process.signal(SignalType.noMemory, "Out of memory");
									return PageFaultStatus.unknownError;
								}
								newCurrentObject.locked = false;
								newCurrentObject.parent = curObject;
								newCurrentObject.refCounter = 1;

								curObject = newCurrentObject;

								page = kernelAllocator.make!VMPage(); // TODO: Reuse old pages
								if (!page) { //TODO: Cleanup
									process.signal(SignalType.noMemory, "Out of memory");
									return PageFaultStatus.unknownError;
								}
								page.vAddr = p.vAddr;
								page.flags = p.flags;
								page.pAddr = PhysAddress(0);
								page.refCounter = 1;

								curObject.pages.put(page);
							} else
								page = p; // Will only happen if it is found in curObject && !curObject.locked
							break outer_2;
						}
					o = o.parent;
				}
			}

			if (!page) {
				process.signal(SignalType.corruptedMemory, "Expected lazy allocation, but cannot find page");
				return PageFaultStatus.unknownError;
			}

			if (page.pAddr) {
				process.signal(SignalType.corruptedMemory, "VMPage is corrupted! PageFault even thou the page is allocated!");
				return PageFaultStatus.unknownError;
			}

			if (write && !(page.flags & VMPageFlags.user) && user) {
				process.signal(SignalType.accessDenied, "User is trying lazy allocate a kernel page");
				return PageFaultStatus.unknownError;
			}

			page.pAddr = backend.getNextFreePage();
			backend.map(page, true);
		}
		return PageFaultStatus.success;
	}

	VMProcess* fork(scope Process process) {
		VMProcess* newProcess = kernelAllocator.make!VMProcess(backend);
		if (!newProcess) {
			process.signal(SignalType.noMemory, "Out of memory");
			return null;
		}

		foreach (VMObject* curObject; objects) {

			// Remap all pages as R/O
			if (!curObject.locked) { // Optimization
				foreach (VMPage* page; curObject.pages)
					if (page.flags & VMPageFlags.writable)
						(*backend).remap(page.vAddr, PhysAddress(), page.flags & ~VMPageFlags.writable);
				curObject.locked = true;
			}

			curObject.refCounter++;

			newProcess.objects.put(curObject);
		}
		return newProcess;
	}

	// Clone does not exist
	// Clone is only this.refCounter++;
	//VMProcess* clone() {}
}

enum PageFaultStatus : ssize_t {
	success = 0,
	unknownError
}

interface IHWPaging { // Hardware implementation of paging
	/// Map virtual address $(PARAM page.vAddr) to physical address $(PARAM page.pAddr) with the flags $(PARAM page.flags).
	/// $(PARAM clear) specifies if the memory should be cleared.
	void map(VMPage* page, bool clear = false);
	/// Map virtual address $(PARAM vAddr) to physical address $(PARAM pAddr) with the flags $(PARAM flags).
	/// $(PARAM clear) specifies if the memory should be cleared.
	void map(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false);

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
	void remap(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags);
	/// Remove a mapping
	void unmap(VirtAddress vAddr);

	/// Clone a physical page with all it's data
	PhysAddress clonePage(PhysAddress page);

	/// Get the next free page
	PhysAddress getNextFreePage();

	/// Free the page $(PARAM page)
	void freePage(PhysAddress page);

	/// Bind the paging
	void bind(IHWMapping mapping);
}

alias PML4Entry = PhysAddress;
alias IHWMapping = VirtAddress; //Map!(ushort /*id*/ , PML4Entry /*entry*/ );

//TODO: MOVE EVERYTHING BELOW!
enum SignalType {
	noMemory,
	kernelError,
	accessDenied,
	corruptedMemory
}

struct Process {
	VMProcess* process;

	void signal(SignalType signal, string error) { //TODO: MOVE!
	}
}
