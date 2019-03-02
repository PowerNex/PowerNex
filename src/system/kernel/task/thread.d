module task.thread;

import stl.vmm.vmm;
import stl.vmm.heap;

import stl.register;
import stl.address;
import stl.vector;
import stl.elf64;

import arch.paging;

// TODO: Move this to runtime init
@safe struct TLS {
	TLS* self;
	ubyte[] tlsData;
	VMThread* thread;

	@disable this();

	static TLS* init(VMThread* thread, bool currentData = true) @trusted {
		/*if (currentData && thread.parent)
			return init(thread, thread.parent.threadState.tls.tlsData);
		else*/

		ELF64ProgramHeader ph = thread.image.elfImage.getProgramHeader(ELF64ProgramHeader.Type.tls);
		return init(thread, ph.vAddr.array!ubyte(ph.memsz));
	}

	static TLS* init(VMThread* thread, ubyte[] data) @trusted {
		//Heap.allocate(data.length + TLS.sizeof).VirtAddress;

		VirtAddress addr = makeAddress(128, 0, 0, 0);
		foreach (size_t i; 0 .. (data.length + TLS.sizeof + 0xFFF) / 0x1000)
			thread.process.mapFreeMemory(thread, addr + i * 0x1000, VMPageFlags.user | VMPageFlags.present | VMPageFlags.writable);
		addr.memcpy(data.VirtAddress, data.length);
		TLS* tls = (addr + data.length).ptr!TLS;
		tls.self = tls;
		tls.tlsData = addr.ptr!ubyte[0 .. data.length];
		tls.thread = thread;
		return tls;
	}

	void destroy() {
		//Heap.free(VirtAddress(tlsData).array!ubyte(tlsData.length + TLS.sizeof));
		thread.process.unmap(thread, tlsData.VirtAddress);
	}
}

@safe struct ImageInfo {
	ELF64 elfImage;
	ELF64Symbol[] symbols;
	const(char)[] symbolStrings;
}

@safe struct ThreadState {
	VirtAddress basePtr; // rbp;
	VirtAddress stackPtr; // rsp;
	VirtAddress instructionPtr; // rip;

	bool fpuEnabled;
	align(16) ubyte[512] fpuStorage;
	TLS* tls;
}

@safe struct VMThread {
	enum State {
		running,
		active,
		sleeping,
		exited,
		killed
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

	size_t pid;
	string name;

	VMProcess* process;

	size_t cpuAssigned;

	State state;
	VirtMemoryRange stack;
	ImageInfo image;

	bool kernelTask;

	size_t niceFactor = 1; // Mean 1 nice factor = 1 time slot.
	// TODO: Modify this to be more like *nix?

	// on State.running
	size_t timeSlotsLeft = 1;

	// on State.active
	ThreadState threadState;
	Registers syscallRegisters;

	// on State.Sleeping
	WaitEvent[] waitsFor;

	//TODO: Add boundaries for this.
	align(64) ubyte[0x4000] kernelStack_ = void;
	@property VirtAddress kernelStack() @trusted {
		return kernelStack_.ptr.VirtAddress + kernelStack_.length;
	}

	void signal(Args...)(SignalType signal, Args args, string file = __MODULE__, string func = __PRETTY_FUNCTION__, int line = __LINE__) {
		import stl.io.log;

		Log.error!(string, SignalType, string, size_t, string, string, string, Args)("[", signal, "][pid:", pid, "][name:",
				name, "] ", args, file, func, line);
		state = State.killed;
	}
}

/// This represents one or more process address spaces (aka, for one or more threads)
@safe struct VMProcess {
public:
	VMObject* vmObject; /// All the object that is associated with the process

	//TODO: Vector!(VMPage*) flattenedPages
	//  This would require either a pointer back the owner VMObject, or add a bool to the page that tells it is it in a
	//  locked VMObject.

	Paging backend; /// The paging backend

	@disable this();

	this(PhysAddress pml4) {
		import stl.vmm.frameallocator;

		if (!pml4)
			backend = Paging.newCleanPaging();
		else
			backend = Paging(pml4, false);

		vmObject = newStruct!VMObject();
		vmObject.refCounter = 1;
		vmObject.state = VMObjectState.unlocked;
	}

	this(ref Paging paging) {
		this(paging.tableAddress);
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

		freeObject(vmObject);
		vmObject = null;
	}

	void bind() @trusted {
		backend.bind();
		if (_needRefresh) {
			//Log.debug_("Refreshing bind!");
			void mapPages(VMObject* obj) {
				if (!obj)
					return;

				mapPages(obj.parent);

				foreach (VMPage* page; obj.pages) {
					VMPageFlags flags = page.flags;
					if (obj.state == VMObjectState.locked && page.type != VMPage.Type.manualMappedPage)
						flags &= ~VMPageFlags.writable;
					if (!page.pAddr && page.type == VMPage.Type.lazyAllocate)
						flags &= ~VMPageFlags.present;

					// TODO: Error checking
					backend.unmap(page.vAddr, false);
					backend.mapAddress(page.vAddr, page.pAddr, flags);
					//Log.verbose("\tMapping ", page.vAddr, " ==> ", page.pAddr, "\ttype: ", page.type);
				}
			}

			mapPages(vmObject);
			//Log.debug_("Refreshing bind is done!");
			_needRefresh = false;
		}
	}

	/**
	 * Decides that to do when a pagefault happens.
	 * Params:
	 *  thread = The thread it happened on.
	 *  vAddr = The address that was accessed
	 *  present = If the page is mapped
	 *  write = If the page is readwrite
	 *  user = If the page is userspace accessable
	 */
	PageFaultStatus onPageFault(VMThread* thread, VirtAddress vAddr, bool present, bool write, bool user) {
		vAddr &= ~0xFFF;

		if (!&this)
			Log.fatal("'this' is null, thread: ", thread, "\tname(", thread.name.length, "): '", thread.name, "'");

		// If present is true, that means that it could be a CoW page. Else it could be a lazy allocation
		if (present) {
			if (!write) {
				if (user)
					thread.signal(VMThread.SignalType.accessDenied, "User is trying to read from a kernel page");
				else if (thread.process.backend.getPhysAddress(vAddr))
					thread.signal(VMThread.SignalType.kernelError, "Kernel is trying to read and caused a protection fault");
				return PageFaultStatus.permissionError;
			}

			// This follow code will only happend, if a page is mapped and the user is trying to write to it.

			VMPage* page;

			// Find the page in the vmObject
			VMObject* o = vmObject;
			outerloop: while (o) {
				foreach (VMPage* p; o.pages)
					if (p.vAddr == vAddr && p.refCounter) {
						page = p;
						break outerloop;
					}
				o = o.parent;
			}

			if (!page) {
				thread.signal(VMThread.SignalType.corruptedMemory, "Expected CoW allocation, but could not find page!");
				return PageFaultStatus.missingPage;
			}

			if (!user && write && page.pAddr && (thread.process.backend.getPageFlags(vAddr) & VMPageFlags.writable)) {
				thread.signal(VMThread.SignalType.kernelError, "Kernel is trying to write to a kernel page and caused a protection fault!");
				return PageFaultStatus.permissionError;
			}

			if (!(page.flags & VMPageFlags.writable)) {
				thread.signal(VMThread.SignalType.accessDenied, "User is trying to write to a read-only page!");
				return PageFaultStatus.permissionError;
			}

			if (page.type != VMPage.Type.cowPage) {
				thread.signal(VMThread.SignalType.corruptedMemory, "Expected CoW allocation, but page type is ", page.type, "!");
				return PageFaultStatus.pageIsWrong;
			}

			bool outOfRam;
			if (!_verifyUnlockedVMObject(thread, outOfRam) /* vmObject is already unlocked */  && o == vmObject) {
				thread.signal(VMThread.SignalType.corruptedMemory, "Expected CoW allocation and the page was in a unlocked VMObject?!");
				return PageFaultStatus.corruptMemory;
			} else if (outOfRam) {
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
				return PageFaultStatus.outOfMemory;
			}

			VMPage* newPage = newStruct!VMPage(); // TODO: Reuse old pages
			if (!newPage) { //TODO: Cleanup
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
				return PageFaultStatus.outOfMemory;
			}
			newPage.type = page.type;
			newPage.vAddr = page.vAddr;
			newPage.flags = page.flags;
			newPage.pAddr = backend.clonePage(page.pAddr);
			newPage.refCounter = 1;
			if (!backend.remap(newPage.vAddr, newPage.pAddr, newPage.flags)) {
				freeStruct(newPage);
				return PageFaultStatus.failedRemap;
			}

			vmObject.pages.put(newPage);
		} else {
			// Here the CPU is trying to access a unmapped page
			// Get the page that correspondence to the vAddr in a non-locked object

			VMPage* page;
			VMObject* o = vmObject;
			outerloop2: while (o) {
				foreach (VMPage* p; o.pages)
					if (p.vAddr == vAddr && p.refCounter) {
						page = p; // Will only happen if it is found in vmObject && vmObject.state == VMObjectState.unlocked
						break outerloop2;
					}
				o = o.parent;
			}

			if (!page) {
				thread.signal(VMThread.SignalType.accessDenied, "Tried to access a unmapped page!");
				return PageFaultStatus.permissionError;
			}

			if (!(page.flags & VMPageFlags.user) && user) {
				thread.signal(VMThread.SignalType.accessDenied, "User is trying lazy allocate a kernel page");
				return PageFaultStatus.permissionError;
			}

			if (page.type != VMPage.Type.lazyAllocate) {
				thread.signal(VMThread.SignalType.accessDenied, "Expected lazy allocation, but page type is ", page.type, "!");
				return PageFaultStatus.unknownError;
			}

			if (page.pAddr) {
				thread.signal(VMThread.SignalType.corruptedMemory, "VMPage is corrupted! PageFault even though the page is allocated!");
				return PageFaultStatus.unknownError;
			}

			bool outOfRam;
			if (_verifyUnlockedVMObject(thread, outOfRam)) {
				VMPage* newPage = newStruct!VMPage();
				if (!page) { //TODO: Cleanup
					thread.signal(VMThread.SignalType.noMemory, "Out of memory");
					return PageFaultStatus.outOfMemory;
				}
				newPage.vAddr = page.vAddr;
				newPage.pAddr = backend.getNextFreePage();
				newPage.flags = page.flags;
				newPage.type = VMPage.Type.cowPage;
				newPage.refCounter = 1;

				if (!backend.remap(newPage.vAddr, newPage.pAddr, newPage.flags)) {
					backend.freePage(newPage.pAddr);
					freeStruct(newPage);
					return PageFaultStatus.failedRemap;
				}

				vmObject.pages.put(newPage);
			} else {
				if (outOfRam) {
					thread.signal(VMThread.SignalType.noMemory, "Out of memory");
					return PageFaultStatus.outOfMemory;
				}

				page.pAddr = backend.getNextFreePage();
				page.type = VMPage.Type.cowPage;
				if (!backend.remap(page.vAddr, page.pAddr, page.flags)) {
					backend.freePage(page.pAddr);
					return PageFaultStatus.failedRemap;
				}
			}
		}
		return PageFaultStatus.success;
	}

	///
	VMProcess* fork(VMThread* thread) {
		if (!&this)
			Log.fatal("'this' is null: ", &this);

		VMProcess* newProcess = newStruct!VMProcess(PhysAddress());
		if (!newProcess) {
			thread.signal(VMThread.SignalType.noMemory, "Out of memory");
			return null;
		}

		if (vmObject.state == VMObjectState.unlocked) {
			foreach (VMPage* page; vmObject.pages)
				if (page.flags & VMPageFlags.writable && page.type == VMPage.Type.cowPage)
					backend.remap(page.vAddr, page.pAddr, page.flags & ~VMPageFlags.writable);

			vmObject.state = VMObjectState.locked;
		}
		newProcess.vmObject.parent = vmObject;
		vmObject.refCounter++;
		newProcess._needRefresh = true;

		return newProcess;
	}

	VMMappingError mapFreeMemory(VMThread* thread, VirtAddress vAddr, VMPageFlags flags) {
		bool outOfRam;
		if (!_verifyUnlockedVMObject(thread, outOfRam) && outOfRam) {
			thread.signal(VMThread.SignalType.noMemory, "Out of memory");
			return VMMappingError.outOfMemory;
		}

		foreach (VMPage* p; vmObject.pages)
			if (p.vAddr == vAddr && p.refCounter)
				return VMMappingError.alreadyMapped;

		VMPage* p = newStruct!VMPage();
		p.type = VMPage.Type.lazyAllocate;
		p.vAddr = vAddr;
		p.pAddr = PhysAddress(0);
		p.flags = flags;
		p.refCounter = 1;

		if (!backend.mapAddress(p.vAddr, p.pAddr, p.flags & ~VMPageFlags.present)) {
			freeStruct(p);
			return VMMappingError.alreadyMapped;
		}

		vmObject.pages.put(p);

		return VMMappingError.success;
	}

	VMMappingError mapManual(VMThread* thread, VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
		bool outOfRam;
		if (!_verifyUnlockedVMObject(thread, outOfRam) && outOfRam) {
			thread.signal(VMThread.SignalType.noMemory, "Out of memory");
			return VMMappingError.outOfMemory;
		}

		foreach (VMPage* p; vmObject.pages)
			if (p.vAddr == vAddr && p.refCounter)
				return VMMappingError.alreadyMapped;

		VMPage* p = newStruct!VMPage();
		p.type = VMPage.Type.manualMappedPage;
		p.vAddr = vAddr;
		p.pAddr = pAddr;
		p.flags = flags;
		p.refCounter = 1;

		if (!backend.mapAddress(p.vAddr, p.pAddr, p.flags)) {
			freeStruct(p);
			return VMMappingError.alreadyMapped;
		}

		vmObject.pages.put(p);

		return VMMappingError.success;
	}

	VMMappingError remap(VMThread* thread, VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags) {
		VMPage* page;
		VMObject* o = vmObject;

		// Search for the VMPage
		outer_loop: while (o) {
			Log.info("Looking at: ", o);
			foreach (VMPage* p; o.pages) {
				Log.info("\tPage: ", p, "\tvAddr: ", p.vAddr, "\trefCounter", p.refCounter);
				if (p.vAddr == vAddr && p.refCounter) {
					page = p;
					break outer_loop;
				}
			}
			o = o.parent;
		}

		if (!page)
			return VMMappingError.mapNotFound;

		bool outOfRam;
		if (_verifyUnlockedVMObject(thread, outOfRam)) {
			VMPage* p = newStruct!VMPage();
			p.type = page.type;
			p.vAddr = vAddr;
			p.pAddr = page.pAddr;
			p.flags = flags;
			p.refCounter = 1;

			if (!backend.remap(p.vAddr, p.pAddr, p.flags)) {
				freeStruct(p);
				return VMMappingError.backendMapNotFound;
			}
			vmObject.pages.put(p);
		} else {
			if (outOfRam) {
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
				return VMMappingError.outOfMemory;
			}

			page.flags = flags;
			page.pAddr = pAddr;
			if (!backend.remap(page.vAddr, pAddr, page.flags))
				return VMMappingError.backendMapNotFound;
		}

		return VMMappingError.success;
	}

	VMMappingError unmap(VMThread* thread, VirtAddress vAddr) {
		VMPage* page;
		VMObject* o = vmObject;
		size_t idx;
		outer_loop: while (o) {
			foreach (i, VMPage* p; o.pages)
				if (p.vAddr == vAddr && p.refCounter) {
					page = p;
					idx = i;
					break outer_loop;
				}
			o = o.parent;
		}
		if (!page)
			return VMMappingError.mapNotFound;

		if (!backend.unmap(page.vAddr))
			return VMMappingError.mapNotFound;

		bool outOfRam;
		if (_verifyUnlockedVMObject(thread, outOfRam)) {
			VMPage* p = newStruct!VMPage();
			p.type = VMPage.Type.free;
			p.vAddr = vAddr;
			p.pAddr = PhysAddress(0);
			p.flags = VMPageFlags.none;
			p.refCounter = 1;

			vmObject.pages.put(p);
		} else {
			if (outOfRam)
				return VMMappingError.unknownError;

			if ((page.type == VMPage.Type.cowPage || page.type == VMPage.Type.lazyAllocate) && page.pAddr)
				backend.freePage(page.pAddr);

			if (o == vmObject)
				freeStruct(vmObject.pages.removeAndGet(idx));
		}

		return VMMappingError.success;
	}

	bool isMapped(VMThread* thread, VirtAddress vAddr) {
		VMObject* o = vmObject;
		while (o) {
			foreach (i, VMPage* p; o.pages)
				if (p.vAddr == vAddr && p.refCounter)
					return true;
			o = o.parent;
		}
		return false;
	}

private:
	bool _needRefresh;

	bool _verifyUnlockedVMObject(VMThread* thread, out bool outOfRam) {
		if (vmObject.state == VMObjectState.locked) { // Replace vmObject
			VMObject* newCurrentObject = newStruct!VMObject();
			if (!newCurrentObject) { //TODO: Cleanup
				thread.signal(VMThread.SignalType.noMemory, "Out of memory");
				outOfRam = true;
				return false;
			}
			newCurrentObject.state = VMObjectState.unlocked;
			newCurrentObject.parent = vmObject;
			newCurrentObject.refCounter = 1;

			vmObject = newCurrentObject;
			return true;
		}
		return false;
	}
}

enum PageFaultStatus {
	success = 0,
	unknownError = -1,
	outOfMemory,
	failedRemap,
	permissionError,
	missingPage,
	pageIsWrong,
	corruptMemory
}
