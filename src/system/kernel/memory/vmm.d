module memory.vmm;

import data.address;
import data.container;
import memory.ptr;
import memory.allocator;
import task.process;
import arch.paging;

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

/// This represents one or more process address spaces
struct VMProcess {
public:
	Vector!(VMObject*) objects; /// All the object that is associated with the process
	IHWPaging backend; /// The paging backend
	@disable this();
	this(IHWPaging backend) {
		objects = kernelAllocator.make!(Vector!(VMObject*))(kernelAllocator);
		backend = backend;
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
					backend.freePage(p.pAddr);

				kernelAllocator.dispose(p);
			}
			kernelAllocator.dispose(o.pages);

			// Free parent
			freeObject(o.parent);

			kernelAllocator.dispose(o);
		}

		foreach (obj; objects)
			freeObject(obj);

		kernelAllocator.dispose(objects);
	}

	void bind() {
		backend.bind();
	}

	//TODO: Return better error
	bool addMemoryZone(VirtAddress zoneStart, VirtAddress zoneEnd, bool isManual = false) {
		// Verify that it won't be inside another zone or contain another zone
		//dfmt off
		foreach (ref VMObject* object; objects)
			if ((object.zoneStart <= zoneStart && object.zoneEnd >= zoneStart) ||	// If zoneStart is inside a existing zone
					(object.zoneStart <= zoneEnd && object.zoneEnd >= zoneEnd) ||			// If zoneEnd is inside a existing zone
					(zoneStart <= object.zoneStart && zoneStart >= object.zoneEnd) ||	// If object.zoneStart is inside the new zone
					(zoneEnd <= object.zoneStart && zoneEnd >= object.zoneEnd))				// If object.zoneEnd is inside the new zone
				return false;
		//dfmt on

		VMObject* obj = kernelAllocator.make!VMObject();
		obj.state = isManual ? VMObjectState.manual : VMObjectState.unlocked;
		obj.zoneStart = zoneStart;
		obj.zoneEnd = zoneEnd;
		obj.pages = kernelAllocator.make!(Vector!(VMPage*))(kernelAllocator);
		obj.parent = null;
		obj.refCounter = 1;

		objects.put(obj);
		return true;
	}

	PageFaultStatus onPageFault(scope Process process, VirtAddress vAddr, bool present, bool write, bool user) {
		auto backend = this.backend;
		vAddr &= ~0xFFF;

		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject) {
			process.signal(SignalType.kernelError, "Can't VMObject for address. SIGSEGV");
			return PageFaultStatus.unknownError;
		} else if ((*rootObject).state == VMObjectState.manual) {
			process.signal(SignalType.kernelError, "Page fault on manual mapped memory");
			return PageFaultStatus.unknownError;
		}

		if (present) {
			if (!write) {
				if (user)
					process.signal(SignalType.accessDenied, "User is trying to read to kernel page");
				else
					process.signal(SignalType.kernelError, "Kernel is trying to read to kernel page");
				return PageFaultStatus.unknownError;
			} else if (user) {
				process.signal(SignalType.accessDenied, "User is trying to write to kernel page");
				return PageFaultStatus.unknownError;
			}

			//CoW
			VMPage* page;

			// If page is found in rootObject && rootObject.state == VMObjectState.locked; then
			//   Allocate new object on top
			// Set obj to the object that should own the page
			// Set page to the page

			VMObject* o = *rootObject;
			if (o.state == VMObjectState.unlocked)
				o = o.parent;
			while (o) {
				foreach (VMPage* p; o.pages)
					if (p.vAddr == vAddr && p.refCounter) {
						if ((*rootObject).state == VMObjectState.locked) { // Replace (*rootObject)
							VMObject* newCurrentObject = kernelAllocator.make!VMObject();
							if (!newCurrentObject) { //TODO: Cleanup
								process.signal(SignalType.noMemory, "Out of memory");
								return PageFaultStatus.unknownError;
							}
							newCurrentObject.state = VMObjectState.unlocked;
							newCurrentObject.parent = (*rootObject);
							newCurrentObject.refCounter = 1;

							(*rootObject) = newCurrentObject;
						}
						page = p;
						break;
					}
				o = o.parent;
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

			(*rootObject).pages.put(newPage);
		} else {
			// Lazy allocation
			VMPage* page;

			// Get the page that correspondence to the vAddr in a non-locked object
			// If it is found in a locked object, allocated a new root unlocked object and
			// allocate a vmpage in that object that will be used.

			VMObject* o = *rootObject;
			while (o) {
				foreach (VMPage* p; o.pages)
					if (p.vAddr == vAddr && p.refCounter) {
						if ((*rootObject).state == VMObjectState.locked) { // Replace (*rootObject)
							VMObject* newCurrentObject = kernelAllocator.make!VMObject();
							if (!newCurrentObject) { //TODO: Cleanup
								process.signal(SignalType.noMemory, "Out of memory");
								return PageFaultStatus.unknownError;
							}
							newCurrentObject.state = VMObjectState.unlocked;
							newCurrentObject.parent = (*rootObject);
							newCurrentObject.refCounter = 1;

							(*rootObject) = newCurrentObject;

							page = kernelAllocator.make!VMPage(); // TODO: Reuse old pages
							if (!page) { //TODO: Cleanup
								process.signal(SignalType.noMemory, "Out of memory");
								return PageFaultStatus.unknownError;
							}
							page.vAddr = p.vAddr;
							page.flags = p.flags;
							page.pAddr = PhysAddress(0);
							page.refCounter = 1;

							(*rootObject).pages.put(page);
						} else
							page = p; // Will only happen if it is found in (*rootObject) && (*rootObject).state == VMObjectState.unlocked
						break;
					}
				o = o.parent;
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

	SharedPtr!VMProcess fork(scope Process process) {
		SharedPtr!VMProcess newProcess = kernelAllocator.makeSharedPtr!VMProcess(backend);
		if (!newProcess) {
			process.signal(SignalType.noMemory, "Out of memory");
			return SharedPtr!VMProcess();
		}

		foreach (obj; objects) {
			// VMObjectState.manual need special handling
			if (obj.state == VMObjectState.manual) {
				VMObject* newObj = kernelAllocator.make!VMObject();
				newObj.state = obj.state;
				newObj.zoneStart = obj.zoneStart;
				newObj.zoneEnd = obj.zoneEnd;
				newObj.pages = kernelAllocator.make!(Vector!(VMPage*))(kernelAllocator);
				foreach (VMPage* p; obj.pages) {
					VMPage* newP = kernelAllocator.make!VMPage();

					newP.vAddr = p.vAddr;
					newP.pAddr = p.pAddr;
					newP.flags = p.flags;
					newP.refCounter = 1; // Because this is a new page, it should be one
					newObj.pages.put(newP);
				}
				newObj.parent = null; // Will always be null
				newObj.refCounter = obj.refCounter;

				(*newProcess).objects.put(newObj);
				continue;
			}

			// Remap all pages as R/O
			if (obj.state == VMObjectState.unlocked) { // Optimization
				foreach (VMPage* page; obj.pages)
					if (page.flags & VMPageFlags.writable)
						backend.remap(page.vAddr, PhysAddress(), page.flags & ~VMPageFlags.writable);
				obj.state = VMObjectState.locked;
			}

			obj.refCounter++;

			(*newProcess).objects.put(obj);
		}

		return newProcess;
	}

	VMMappingError mapFreeMemory(scope Process process, VirtAddress vAddr, VMPageFlags flags) {
		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject)
			return VMMappingError.noMemoryZoneAllocated;
		else if ((*rootObject).state == VMObjectState.manual)
			return VMMappingError.notSupportedMap; // map(vAddr, pAddr) maps are only allowed in VMObjectState.manual

		if ((*rootObject).state == VMObjectState.locked) { // Replace (*rootObject)
			VMObject* newCurrentObject = kernelAllocator.make!VMObject();
			if (!newCurrentObject) { //TODO: Cleanup
				process.signal(SignalType.noMemory, "Out of memory");
				return VMMappingError.outOfMemory;
			}
			newCurrentObject.state = VMObjectState.unlocked;
			newCurrentObject.parent = (*rootObject);
			newCurrentObject.refCounter = 1;

			(*rootObject) = newCurrentObject;
		}

		foreach (VMPage* p; (*rootObject).pages)
			if (p.vAddr == vAddr && p.refCounter)
				return VMMappingError.alreadyMapped;

		VMPage* p = kernelAllocator.make!VMPage();
		p.vAddr = vAddr;
		p.pAddr = PhysAddress(0);
		p.flags = flags;

		(*rootObject).pages.put(p);
		return VMMappingError.success;
	}

	VMMappingError mapManual(scope Process process, VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject)
			return VMMappingError.noMemoryZoneAllocated;
		else if ((*rootObject).state != VMObjectState.manual)
			return VMMappingError.notSupportedMap; // map(vAddr, pAddr) maps are only allowed in VMObjectState.manual

		foreach (VMPage* p; (*rootObject).pages)
			if (p.vAddr == vAddr && p.refCounter)
				return VMMappingError.alreadyMapped;

		VMPage* p = kernelAllocator.make!VMPage();
		p.vAddr = vAddr;
		p.pAddr = pAddr;
		p.flags = flags;

		(*rootObject).pages.put(p);
		return VMMappingError.success;
	}

	VMMappingError remap(scope Process process, VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject)
			return VMMappingError.noMemoryZoneAllocated;

		VMPage* page;
		VMObject* o = *rootObject;

		// Search for the VMPage
		outer_loop: while (o) {
			foreach (VMPage* p; o.pages)
				if (p.vAddr == vAddr && p.refCounter) {
					page = p;
					p.flags = flags;
					if (pAddr)
						p.pAddr = pAddr;
					if ((*rootObject) == o && (*rootObject).state != VMObjectState.locked) //if ((!(flags & VMPageFlags.writable) && (p.flags & VMPageFlags.writable)))
						return backend.remap(p.vAddr, pAddr, p.flags) ? VMMappingError.success : VMMappingError.unknownError;
					break outer_loop;
				}
			o = o.parent;
		}

		if (!page)
			return VMMappingError.mapNotFound;

		// If the code reaches here we know that the state is VMObjectState.locked or *rootObject != o

		if ((*rootObject).state == VMObjectState.locked) { // Replace (*rootObject)
			VMObject* newCurrentObject = kernelAllocator.make!VMObject();
			if (!newCurrentObject) { //TODO: Cleanup
				process.signal(SignalType.noMemory, "Out of memory");
				return VMMappingError.outOfMemory;
			}
			newCurrentObject.state = VMObjectState.unlocked;
			newCurrentObject.parent = (*rootObject);
			newCurrentObject.refCounter = 1;

			(*rootObject) = newCurrentObject;
		}

		VMPage* p = kernelAllocator.make!VMPage();
		p.vAddr = vAddr;
		p.pAddr = page.pAddr;
		p.flags = flags;

		(*rootObject).pages.put(p);
		return VMMappingError.success;
	}

	VMMappingError unmap(scope Process process, VirtAddress vAddr) {
		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject)
			return VMMappingError.noMemoryZoneAllocated;

		VMPage* page;
		VMObject* o = *rootObject;
		outer_loop: while (o) {
			foreach (VMPage* p; o.pages)
				if (p.vAddr == vAddr && p.refCounter) {
					page = p;
					if ((*rootObject) == o && (*rootObject).state != VMObjectState.locked) {
						if (p.pAddr) {
							backend.freePage(p.pAddr); //TODO: check output?
							p.pAddr = PhysAddress(0);
						}
						p.refCounter = 0; //TODO: Actually use refCounter
						return VMMappingError.success;
					}
					break outer_loop;
				}
			o = o.parent;
		}
		if (!page)
			return VMMappingError.mapNotFound;

		if ((*rootObject).state == VMObjectState.locked) { // Replace (*rootObject)
			VMObject* newCurrentObject = kernelAllocator.make!VMObject();
			if (!newCurrentObject) { //TODO: Cleanup
				process.signal(SignalType.noMemory, "Out of memory");
				return VMMappingError.outOfMemory;
			}
			newCurrentObject.state = VMObjectState.unlocked;
			newCurrentObject.parent = (*rootObject);
			newCurrentObject.refCounter = 1;

			(*rootObject) = newCurrentObject;
		}

		VMPage* p = kernelAllocator.make!VMPage();
		p.vAddr = vAddr;
		p.pAddr = PhysAddress(0);
		p.flags = VMPageFlags.none;
		p.refCounter = 0;

		(*rootObject).pages.put(p);
		return VMMappingError.success;
	}

private:
	VMObject** _getObjectForZone(VirtAddress addr) {
		foreach (ref VMObject* object; objects)
			if (object.zoneStart <= addr && object.zoneEnd >= addr)
				return &object;
		return null;
	}
}

enum PageFaultStatus : ssize_t {
	success = 0,
	unknownError = -1
}

// TODO: Change bool -> void/PagingError?
