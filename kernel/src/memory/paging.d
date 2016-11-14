module memory.paging;

import data.address;
import data.bitfield;
import memory.frameallocator;
import io.log;
import data.linker;

extern (C) void cpuFlushPage(ulong addr);

enum MapMode : ulong { // TODO: Implement the rest.
	present = 1 << 0,
	writable = 1 << 1,
	user = 1 << 2,
	map4M = 1 << 8,
	noExecute = 1UL << 63,

	empty = 0,
	defaultKernel = present | writable,
	defaultUser = present | user | writable
}

struct TablePtr(T) {
	private ulong _data;

	this(TablePtr!T other) {
		_data = other.data;
	}

	@property PhysAddress data(PhysAddress address) {
		this.address = address.num >> 12;
		return data();
	}

	@property PhysAddress data() {
		return PhysAddress(address << 12);
	}

	@property MapMode mode(MapMode mode) {
		readWrite = !!(mode & MapMode.writable);
		user = !!(mode & MapMode.user);
		static if (!is(T == void))
			map4M = !!(mode & MapMode.map4M);
		noExecute = !!(mode & MapMode.noExecute);

		return this.mode();
	}

	@property MapMode mode() {
		MapMode mode;

		if (present)
			mode |= MapMode.present;

		if (readWrite)
			mode |= MapMode.writable;
		if (user)
			mode |= MapMode.user;
		static if (!is(T == void))
			if (map4M)
				mode |= MapMode.map4M;
		if (noExecute)
			mode |= MapMode.noExecute;

		return mode;
	}

	//dfmt off
	static if (is(T == void)) {
		mixin(bitfield!(_data,
		"present", 1,
		"readWrite", 1,
		"user", 1,
		"writeThrough", 1,
		"cacheDisable", 1,
		"accessed", 1,
		"dirty", 1,
		"pat", 1,
		"global", 1,
		"avl", 3,
		"address", 40,
		"available", 11,
		"noExecute", 1
		));
	} else {
		mixin(bitfield!(_data,
		"present", 1,
		"readWrite", 1,
		"user", 1,
		"writeThrough", 1,
		"cacheDisable", 1,
		"accessed", 1,
		"reserved", 1,
		"map4M", 1,
		"ignored", 1,
		"avl", 3,
		"address", 40,
		"available", 11,
		"noExecute", 1
		));
	}
	//dfmt on
}

static assert(TablePtr!void.sizeof == ulong.sizeof);

struct Table(int Level) {
	static if (Level == 1)
		alias ChildType = TablePtr!(void);
	else
		alias ChildType = TablePtr!(Table!(Level - 1));

	ChildType[512] children;

	ChildType* get(ushort idx) {
		assert(idx < children.length);
		ChildType* child = &children[idx];
		return child;
	}

	static if (Level != 1)
		ChildType* getOrCreate(ushort idx, MapMode mode) {
			assert(idx < children.length);
			ChildType* child = &children[idx];

			if (!child.present) {
				if (mode & MapMode.map4M)
					log.fatal("Map4M creation is not Allowed in GetOrCreate! Level: ", Level, " Index: ", idx);

				child.data = PhysAddress(FrameAllocator.alloc());

				_memset64(child.data.virtual.ptr, 0, 0x200); //Defined in object.d, 0x200 * 8 = 0x1000

				child.mode = mode;
				child.present = true;
			}

			return child;
		}
}

static assert(Table!4.sizeof == (ulong[512]).sizeof);

private extern (C) void cpuInstallCR3(PhysAddress addr);

class Paging {
public:
	private this() {
		_rootPhys = PhysAddress(FrameAllocator.alloc());
		_root = _rootPhys.virtual.ptr!(Table!4);
		_memset64(_root, 0, 0x200); //Defined in object.d
		_refCounter++;
	}

	this(void* pml4) {
		_root = cast(Table!4*)pml4;
		_refCounter++;
		_rootPhys = getPage(VirtAddress(_root)).data;
	}

	this(Paging other) {
		this();

		Table!4* otherPML4 = other._root;
		Table!4* myPML4 = _root;
		for (ushort pml4Idx = 0; pml4Idx < 512 - 1 /* Kernel PDP */ ; pml4Idx++) {
			if (pml4Idx == 256) // See end of function for why
				continue;

			TablePtr!(Table!3) otherPDPEntry_ptr = otherPML4.children[pml4Idx];
			if (!otherPDPEntry_ptr.present)
				continue;

			Table!3* otherPDPEntry = otherPDPEntry_ptr.data.virtual.ptr!(Table!3);
			Table!3* myPDPEntry = myPML4.getOrCreate(pml4Idx, otherPDPEntry_ptr.mode).data.virtual.ptr!(Table!3);

			for (ushort pdpIdx = 0; pdpIdx < 512; pdpIdx++) {
				TablePtr!(Table!2) otherPDEntry_ptr = otherPDPEntry.children[pdpIdx];
				if (!otherPDEntry_ptr.present)
					continue;

				Table!2* otherPDEntry = otherPDEntry_ptr.data.virtual.ptr!(Table!2);
				Table!2* myPDEntry = myPDPEntry.getOrCreate(pdpIdx, otherPDEntry_ptr.mode).data.virtual.ptr!(Table!2);

				for (ushort pdIdx = 0; pdIdx < 512; pdIdx++) {
					TablePtr!(Table!1) otherPTEntry_ptr = otherPDEntry.children[pdIdx];
					if (!otherPTEntry_ptr.present)
						continue;

					if (otherPTEntry_ptr.mode & MapMode.map4M) {
						TablePtr!(Table!1)* myPTEntry = myPDEntry.get(pdIdx);
						PhysAddress phys = PhysAddress(FrameAllocator.alloc512());
						myPTEntry.data = phys;
						myPTEntry.mode = otherPTEntry_ptr.mode;
						myPTEntry.present = true;
						VirtAddress addr = VirtAddress(cast(ulong)pml4Idx << 39UL | cast(ulong)pdpIdx << 30UL | cast(ulong)pdIdx << 21UL);

						flushPage(addr);
						memcpy(phys.virtual.ptr, otherPTEntry_ptr.data.virtual.ptr, 0x1000 * 512); //Defined in object.d, 0x200 * 8 = 0x1000
					} else {
						Table!1* otherPTEntry = otherPTEntry_ptr.data.virtual.ptr!(Table!1);
						Table!1* myPTEntry = myPDEntry.getOrCreate(pdIdx, otherPTEntry_ptr.mode).data.virtual.ptr!(Table!1);

						for (ushort ptIdx = 0; ptIdx < 512; ptIdx++) {
							PhysAddress phys = FrameAllocator.alloc();
							assert(phys.num);
							with (myPTEntry.children[ptIdx]) {
								data = phys;
								mode = otherPTEntry.children[ptIdx].mode;
								present = true;
							}

							VirtAddress addr = VirtAddress(cast(ulong)pml4Idx << 39UL | cast(ulong)pdpIdx << 30UL | cast(
									ulong)pdIdx << 21UL | cast(ulong)ptIdx << 12UL);
							flushPage(addr);

							memcpy(phys.virtual.ptr, otherPTEntry.children[ptIdx].data.virtual.ptr, 0x1000); // TODO: Implement Copy-on-write, so we can skip this step!
						}
					}
				}
			}
		}
		myPML4.children[256] = otherPML4.children[256]; // 512GiB Lower mapping
		myPML4.children[511] = otherPML4.children[511]; // Map Kernel
	}

	void map(VirtAddress virt, PhysAddress phys, MapMode pageMode, MapMode tablesMode = MapMode.defaultUser) {
		if (phys.num == 0)
			return;
		const ulong virtAddr = virt.num;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		Table!3* pdp = _root.getOrCreate(pml4Idx, tablesMode).data.virtual.ptr!(Table!3);
		Table!2* pd = pdp.getOrCreate(pdpIdx, tablesMode).data.virtual.ptr!(Table!2);
		Table!1* pt = pd.getOrCreate(pdIdx, tablesMode).data.virtual.ptr!(Table!1);
		TablePtr!void* page = pt.get(ptIdx);

		page.mode = pageMode;
		page.data = phys;
		page.present = true;
		flushPage(virt);
	}

	void unmap(VirtAddress virt) {
		auto page = getPage(virt);
		if (!page)
			return;

		page.mode = MapMode.empty;
		page.data = PhysAddress();
		page.present = false;
		flushPage(virt);
	}

	void unmapAndFree(VirtAddress virt) {
		auto page = getPage(virt);
		if (!page)
			return;

		FrameAllocator.free(page.data);

		page.mode = MapMode.empty;
		page.data = PhysAddress();
		page.present = false;
		flushPage(virt);
	}

	PhysAddress mapFreeMemory(VirtAddress virt, MapMode pageMode, MapMode tablesMode = MapMode.defaultUser) {
		PhysAddress phys = FrameAllocator.alloc();
		if (!phys.num)
			return phys; // aka Null
		map(virt, phys, pageMode, tablesMode);
		return phys;
	}

	TablePtr!(void)* getPage(VirtAddress virt) {
		if (virt.num == 0)
			return null;
		const ulong virtAddr = virt.num;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		auto pdpAddr = _root.get(pml4Idx);
		if (!pdpAddr.present)
			return null;
		Table!3* pdp = pdpAddr.data.virtual.ptr!(Table!3);

		auto pdAddr = pdp.get(pdpIdx);
		if (!pdAddr.present)
			return null;
		Table!2* pd = pdAddr.data.virtual.ptr!(Table!2);

		auto ptAddr = pd.get(pdIdx);
		if (!ptAddr.present)
			return null;
		Table!1* pt = ptAddr.data.virtual.ptr!(Table!1);

		return pt.get(ptIdx);
	}

	void install() {
		cpuInstallCR3(root());
	}

	void removeUserspace(bool freePages) {
		Table!4* myPML4 = _root;
		for (ushort pml4Idx = 0; pml4Idx < 512 - 1 /* Kernel PDP */ ; pml4Idx++) {
			if (pml4Idx == 256) // 512GiB Lower mapping
				continue;

			auto pdp_ptr = myPML4.get(pml4Idx);
			if (!pdp_ptr.present)
				continue;
			Table!3* myPDPEntry = pdp_ptr.data.virtual.ptr!(Table!3);

			for (ushort pdpIdx = 0; pdpIdx < 512; pdpIdx++) {
				auto pd_ptr = myPDPEntry.get(pdpIdx);
				if (!pd_ptr.present)
					continue;
				Table!2* myPDEntry = pd_ptr.data.virtual.ptr!(Table!2);

				for (ushort pdIdx = 0; pdIdx < 512; pdIdx++) {
					auto pt_ptr = myPDEntry.get(pdIdx);
					if (!pt_ptr.present)
						continue;

					if (pt_ptr.mode & MapMode.map4M) {
						PhysAddress start = pt_ptr.data;
						immutable PhysAddress end = start + 512 * 0x1000;
						while (start < end)
							FrameAllocator.free(start += 0x1000);
					} else {
						Table!1* myPTEntry = pt_ptr.data.virtual.ptr!(Table!1);

						if (freePages)
							for (ushort ptIdx = 0; ptIdx < 512; ptIdx++)
								with (myPTEntry.get(ptIdx))
									if (present) {
										VirtAddress addr = VirtAddress(cast(ulong)pml4Idx << 39UL | cast(
												ulong)pdpIdx << 30UL | cast(ulong)pdIdx << 21UL | cast(ulong)ptIdx << 12UL);
										FrameAllocator.free(data);
										present = false;
										flushPage(addr);
									}

						//log.warning("Freeing Table!1: ", VirtAddress(cast(ulong)pml4Idx << 39UL | cast(ulong)pdpIdx << 30UL | cast(ulong)pdIdx << 21UL));
						FrameAllocator.free(pt_ptr.data);
					}
				}
				//log.warning("Freeing Table!2: ", VirtAddress(cast(ulong)pml4Idx << 39UL | cast(ulong)pdpIdx << 30UL));
				FrameAllocator.free(pd_ptr.data);
			}
			//log.warning("Freeing Table!3: ", VirtAddress(cast(ulong)pml4Idx << 39UL));
			FrameAllocator.free(pdp_ptr.data);
			pdp_ptr.mode = MapMode.empty;
			pdp_ptr.data = PhysAddress();
			pdp_ptr.present = false;
		}
	}

	void flushPage(VirtAddress virt) {
		cpuFlushPage(virt.num);
	}

	@property Table!4* rootTable() {
		return _root;
	}

	@property PhysAddress root() {
		return _rootPhys;
	}

	@property ref ulong refCounter() {
		return _refCounter;
	}

private:
	Table!4* _root;
	PhysAddress _rootPhys;
	ulong _refCounter;
}

private extern (C) extern __gshared {
	ubyte PML4; // Reference to PML4 in boot.S
}

Paging getKernelPaging() {
	import data.util : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, Paging)] data;
	__gshared Paging kernelPaging;

	if (!kernelPaging)
		kernelPaging = inplaceClass!Paging(data, &PML4);
	return kernelPaging;
}
