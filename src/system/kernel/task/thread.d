module task.thread;

import stl.vmm.vmm;
import stl.vmm.heap;

import stl.register;
import stl.address;
import stl.vector;

import arch.paging;

@safe struct ThreadState {
	VirtAddress basePtr; // rbp;
	VirtAddress stackPtr; // rsp;
	VirtAddress instructionPtr; // rip;

	VirtAddress tls;
	bool fpuEnabled;
	align(64) ubyte[0x2000] fpuStorage;
	//TLS* tls;

	Paging* paging;
}

@safe struct VMThread {
	enum State {
		running,
		active,
		sleeping,
		exited
	}

	enum WaitEvent {
		keyboard,
		timer,
		mutex,
		join
	}

	enum SignalType {
		noMemory,
		kernelError,
		accessDenied,
		corruptedMemory
	}

	VMProcess* process;

	size_t cpuAssigned;

	State state;
	VirtMemoryRange stack;

	bool kernelTask;

	// on State.active
	ThreadState threadState;
	Registers syscallRegisters;

	// on State.Sleeping
	WaitEvent[] waitsFor;

	void signal(SignalType signal, string error) {
	}
}

/// This represents one or more process address spaces (aka, for one or more threads)
@safe struct VMProcess {
public:
	Vector!(VMObject*) objects; /// All the object that is associated with the process
	Paging backend; /// The paging backend

	@disable this();

	this(PhysAddress pml4) {
		import stl.vmm.frameallocator;

		if (!pml4) {
			pml4 = FrameAllocator.alloc();
			auto virt = mapSpecialAddress(pml4, 0x1000, true, true);
			unmapSpecialAddress(virt, 0x1000);
			backend = Paging(pml4, true);
		} else
			backend = Paging(pml4, false);
	}

	this(ref Paging paging) {
		backend = Paging(paging);
	}

	@disable this(this);

	~this() {
		// Don't unmap anything, it will just waste performance.
		// This VMProcess is dead when this is called, just GC everything.
		void freeObject(VMObject* o) @trusted {
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

				freeStruct(p);
			}
			o.pages.clear();

			// Free parent
			freeObject(o.parent);

			freeStruct(o);
		}

		foreach (obj; objects)
			freeObject(obj);

		objects.clear();
	}

	void bind() @trusted {
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

		VMObject* obj = newStruct!VMObject();
		obj.state = isManual ? VMObjectState.manual : VMObjectState.unlocked;
		obj.zoneStart = zoneStart;
		obj.zoneEnd = zoneEnd;
		obj.parent = null;
		obj.refCounter = 1;

		objects.put(obj);
		return true;
	}

	PageFaultStatus onPageFault(VMThread* thread, VirtAddress vAddr, bool present, bool write, bool user) {
		vAddr &= ~0xFFF;

		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject) {
			thread.signal(VMThread.SignalType.kernelError, "Can't VMObject for address. SIGSEGV");
			return PageFaultStatus.unknownError;
		} else if ((*rootObject).state == VMObjectState.manual) {
			thread.signal(VMThread.SignalType.kernelError, "Page fault on manual mapped memory");
			return PageFaultStatus.unknownError;
		}

		if (present) {
			if (!write) {
				if (user)
					thread.signal(VMThread.SignalType.accessDenied, "User is trying to read to kernel page");
				else
					thread.signal(VMThread.SignalType.kernelError, "Kernel is trying to read to kernel page");
				return PageFaultStatus.unknownError;
			} else if (user) {
				thread.signal(VMThread.SignalType.accessDenied, "User is trying to write to kernel page");
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
							VMObject* newCurrentObject = newStruct!VMObject();
							if (!newCurrentObject) { //TODO: Cleanup
								thread.signal(VMThread.SignalType.noMemory, "Out of memory");
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
				thread.signal(VMThread.SignalType.corruptedMemory, "Expected CoW allocation, but could not find page");
				return PageFaultStatus.unknownError;
			}

			VMPage* newPage = newStruct!VMPage(); // TODO: Reuse old pages
			if (!newPage) { //TODO: Cleanup
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
				return PageFaultStatus.unknownError;
			}
			newPage.vAddr = vAddr;
			newPage.flags = page.flags;
			newPage.pAddr = backend.clonePage(page.pAddr);
			newPage.refCounter = 1;
			backend.mapVMPage(newPage);

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
							VMObject* newCurrentObject = newStruct!VMObject();
							if (!newCurrentObject) { //TODO: Cleanup
								thread.signal(VMThread.SignalType.noMemory, "Out of memory");
								return PageFaultStatus.unknownError;
							}
							newCurrentObject.state = VMObjectState.unlocked;
							newCurrentObject.parent = (*rootObject);
							newCurrentObject.refCounter = 1;

							(*rootObject) = newCurrentObject;

							page = newStruct!VMPage(); // TODO: Reuse old pages
							if (!page) { //TODO: Cleanup
								thread.signal(VMThread.SignalType.noMemory, "Out of memory");
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
				thread.signal(VMThread.SignalType.corruptedMemory, "Expected lazy allocation, but cannot find page");
				return PageFaultStatus.unknownError;
			}

			if (page.pAddr) {
				thread.signal(VMThread.SignalType.corruptedMemory, "VMPage is corrupted! PageFault even thou the page is allocated!");
				return PageFaultStatus.unknownError;
			}

			if (write && !(page.flags & VMPageFlags.user) && user) {
				thread.signal(VMThread.SignalType.accessDenied, "User is trying lazy allocate a kernel page");
				return PageFaultStatus.unknownError;
			}

			page.pAddr = backend.getNextFreePage();
			backend.mapVMPage(page, true);
		}
		return PageFaultStatus.success;
	}

	VMProcess* fork(VMThread* thread) {
		VMProcess* newProcess = newStruct!VMProcess(backend);
		if (!newProcess) {
			thread.signal(VMThread.SignalType.noMemory, "Out of memory");
			return null;
		}

		foreach (obj; objects) {
			// VMObjectState.manual need special handling
			if (obj.state == VMObjectState.manual) {
				VMObject* newObj = newStruct!VMObject();
				newObj.state = obj.state;
				newObj.zoneStart = obj.zoneStart;
				newObj.zoneEnd = obj.zoneEnd;
				foreach (VMPage* p; obj.pages) {
					VMPage* newP = newStruct!VMPage();

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

	VMMappingError mapFreeMemory(VMThread* thread, VirtAddress vAddr, VMPageFlags flags) {
		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject)
			return VMMappingError.noMemoryZoneAllocated;
		else if ((*rootObject).state == VMObjectState.manual)
			return VMMappingError.notSupportedMap; // map(vAddr, pAddr) maps are only allowed in VMObjectState.manual

		if ((*rootObject).state == VMObjectState.locked) { // Replace (*rootObject)
			VMObject* newCurrentObject = newStruct!VMObject();
			if (!newCurrentObject) { //TODO: Cleanup
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
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

		VMPage* p = newStruct!VMPage();
		p.vAddr = vAddr;
		p.pAddr = PhysAddress(0);
		p.flags = flags;

		(*rootObject).pages.put(p);
		return VMMappingError.success;
	}

	VMMappingError mapManual(VMThread* thread, VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
		VMObject** rootObject = _getObjectForZone(vAddr);
		if (!rootObject)
			return VMMappingError.noMemoryZoneAllocated;
		else if ((*rootObject).state != VMObjectState.manual)
			return VMMappingError.notSupportedMap; // map(vAddr, pAddr) maps are only allowed in VMObjectState.manual

		foreach (VMPage* p; (*rootObject).pages)
			if (p.vAddr == vAddr && p.refCounter)
				return VMMappingError.alreadyMapped;

		VMPage* p = newStruct!VMPage();
		p.vAddr = vAddr;
		p.pAddr = pAddr;
		p.flags = flags;

		(*rootObject).pages.put(p);
		return VMMappingError.success;
	}

	VMMappingError remap(VMThread* thread, VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
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
			VMObject* newCurrentObject = newStruct!VMObject();
			if (!newCurrentObject) { //TODO: Cleanup
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
				return VMMappingError.outOfMemory;
			}
			newCurrentObject.state = VMObjectState.unlocked;
			newCurrentObject.parent = (*rootObject);
			newCurrentObject.refCounter = 1;

			(*rootObject) = newCurrentObject;
		}

		VMPage* p = newStruct!VMPage();
		p.vAddr = vAddr;
		p.pAddr = page.pAddr;
		p.flags = flags;

		(*rootObject).pages.put(p);
		return VMMappingError.success;
	}

	VMMappingError unmap(VMThread* thread, VirtAddress vAddr) {
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
			VMObject* newCurrentObject = newStruct!VMObject();
			if (!newCurrentObject) { //TODO: Cleanup
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
				return VMMappingError.outOfMemory;
			}
			newCurrentObject.state = VMObjectState.unlocked;
			newCurrentObject.parent = (*rootObject);
			newCurrentObject.refCounter = 1;

			(*rootObject) = newCurrentObject;
		}

		VMPage* p = newStruct!VMPage();
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

enum PageFaultStatus {
	success = 0,
	unknownError = -1
}
