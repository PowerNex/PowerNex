module Memory.Paging;

import Data.Address;
import Data.BitField;
import Memory.FrameAllocator;
import IO.Log;
import Data.Linker;

enum MapMode : ulong { // TODO: Implement the rest.
	Present = 1 << 0,
	Writable = 1 << 1,
	User = 1 << 2,
	PageSize = 1 << 8,
	NotExecutable = 1UL << 63,

	Empty = 0,
	DefaultKernel = Present | Writable,
	DefaultUser = Present | User | Writable
}

struct TablePtr(T) {
	ulong data;

	this(TablePtr!T other) {
		data = other.data;
	}

	@property PhysAddress Data(PhysAddress address) {
		Address = address.Int >> 12;
		return Data();
	}

	@property PhysAddress Data() {
		return PhysAddress(Address << 12);
	}

	@property MapMode Mode(MapMode mode) {
		ReadWrite = !!(mode & MapMode.Writable);
		User = !!(mode & MapMode.User);
		static if (!is(T == void))
			PageSize = !!(mode & MapMode.PageSize);
		NotExecutable = !!(mode & MapMode.NotExecutable);

		return Mode();
	}

	@property MapMode Mode() {
		MapMode mode;

		if (Present)
			mode |= MapMode.Present;

		if (ReadWrite)
			mode |= MapMode.Writable;
		if (User)
			mode |= MapMode.User;
		static if (!is(T == void))
			if (PageSize)
				mode |= MapMode.PageSize;
		if (NotExecutable)
			mode |= MapMode.NotExecutable;

		return mode;
	}

	//dfmt off
	static if (is(T == void)) {
		mixin(Bitfield!(data,
		"Present", 1,
		"ReadWrite", 1,
		"User", 1,
		"WriteThrough", 1,
		"CacheDisable", 1,
		"Accessed", 1,
		"Dirty", 1,
		"PAT", 1,
		"Global", 1,
		"Avl", 3,
		"Address", 40,
		"Available", 11,
		"NotExecutable", 1
		));
	} else {
		mixin(Bitfield!(data,
		"Present", 1,
		"ReadWrite", 1,
		"User", 1,
		"WriteThrough", 1,
		"CacheDisable", 1,
		"Accessed", 1,
		"Reserved", 1,
		"PageSize", 1,
		"Ignored", 1,
		"Avl", 3,
		"Address", 40,
		"Available", 11,
		"NotExecutable", 1
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

	ChildType* Get(ushort idx) {
		assert(idx < children.length);
		ChildType* child = &children[idx];
		static if (Level != 1)
			if (child.Present && child.PageSize)
				log.Fatal("PageSize handling is not implemented!");

		return child;
	}

	static if (Level != 1)
		ChildType* GetOrCreate(ushort idx, MapMode mode) {
			assert(idx < children.length);
			ChildType* child = &children[idx];

			if (child && !child.Present) {
				child.Data = PhysAddress(FrameAllocator.Alloc());
				child.Mode = mode;
				child.Present = true;
				_memset64(child.Data.Virtual.Ptr, 0, 0x200); //Defined in object.d, 0x200 * 8 = 0x1000
			} else if (child.PageSize)
				log.Fatal("PageSize handling is not implemented!");

			return child;
		}
}

static assert(Table!4.sizeof == (ulong[512]).sizeof);

private extern (C) void CPU_install_cr3(PhysAddress addr);

class Paging {
public:
	this() {
		rootPhys = PhysAddress(FrameAllocator.Alloc());
		root = rootPhys.Virtual.Ptr!(Table!4);
		_memset64(root, 0, 0x200); //Defined in object.d
		refCounter++;
	}

	this(void* pml4) {
		root = cast(Table!4*)pml4;
		refCounter++;
		rootPhys = GetPage(VirtAddress(root)).Data;
	}

	this(Paging other) {
		this();

		Table!4* otherPML4 = other.root;
		Table!4* myPML4 = root;
		for (ushort pml4Idx = 0; pml4Idx < 512 - 1; pml4Idx++) {
			TablePtr!(Table!3) otherPDPEntry_ptr = otherPML4.children[pml4Idx];
			if (!otherPDPEntry_ptr.Present)
				continue;

			Table!3* otherPDPEntry = otherPDPEntry_ptr.Data.Virtual.Ptr!(Table!3);
			Table!3* myPDPEntry = myPML4.GetOrCreate(pml4Idx, otherPDPEntry_ptr.Mode).Data.Virtual.Ptr!(Table!3);

			for (ushort pdpIdx = 0; pdpIdx < 512; pdpIdx++) {
				TablePtr!(Table!2) otherPDEntry_ptr = otherPDPEntry.children[pdpIdx];
				if (!otherPDEntry_ptr.Present)
					continue;

				Table!2* otherPDEntry = otherPDEntry_ptr.Data.Virtual.Ptr!(Table!2);
				Table!2* myPDEntry = myPDPEntry.GetOrCreate(pdpIdx, otherPDEntry_ptr.Mode).Data.Virtual.Ptr!(Table!2);

				for (ushort pdIdx = 0; pdIdx < 512; pdIdx++) {
					TablePtr!(Table!1) otherPTEntry_ptr = otherPDEntry.children[pdIdx];
					if (!otherPTEntry_ptr.Present)
						continue;

					Table!1* otherPTEntry = otherPTEntry_ptr.Data.Virtual.Ptr!(Table!1);
					Table!1* myPTEntry = myPDEntry.GetOrCreate(pdIdx, otherPTEntry_ptr.Mode).Data.Virtual.Ptr!(Table!1);

					for (ushort ptIdx = 0; ptIdx < 512; ptIdx++)
						myPTEntry.children[ptIdx].data = otherPTEntry.children[ptIdx].data;
				}
			}
		}
		myPML4.children[511] = otherPML4.children[511]; // Map Kernel
	}

	void Map(VirtAddress virt, PhysAddress phys, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) {
		if (phys.Int == 0)
			return;
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		Table!3* pdp = root.GetOrCreate(pml4Idx, tablesMode).Data.Virtual.Ptr!(Table!3);
		Table!2* pd = pdp.GetOrCreate(pdpIdx, tablesMode).Data.Virtual.Ptr!(Table!2);
		Table!1* pt = pd.GetOrCreate(pdIdx, tablesMode).Data.Virtual.Ptr!(Table!1);
		TablePtr!void* page = pt.Get(ptIdx);

		page.Mode = pageMode;
		page.Data = phys;
		page.Present = true;
	}

	void Unmap(VirtAddress virt) {
		auto page = GetPage(virt);
		if (!page)
			return;

		page.Mode = MapMode.Empty;
		page.Data = PhysAddress();
		page.Present = false;
	}

	void UnmapAndFree(VirtAddress virt) {
		auto page = GetPage(virt);
		if (!page)
			return;

		FrameAllocator.Free(PhysAddress(page.Data));

		page.Mode = MapMode.Empty;
		page.Data = PhysAddress();
		page.Present = false;
	}

	PhysAddress MapFreeMemory(VirtAddress virt, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) {
		PhysAddress phys = FrameAllocator.Alloc();
		if (!phys.Int)
			return phys;
		Map(virt, phys, pageMode, tablesMode);
		_memset64(virt.Ptr, 0, 0x200); //Defined in object.d
		return phys;
	}

	TablePtr!(void)* GetPage(VirtAddress virt) {
		if (virt.Int == 0)
			return null;
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		auto pdpAddr = root.Get(pml4Idx);
		if (!pdpAddr.Present)
			return null;
		Table!3* pdp = pdpAddr.Data.Virtual.Ptr!(Table!3);

		auto pdAddr = pdp.Get(pdpIdx);
		if (!pdAddr.Present)
			return null;
		Table!2* pd = pdAddr.Data.Virtual.Ptr!(Table!2);

		auto ptAddr = pd.Get(pdIdx);
		if (!ptAddr.Present)
			return null;
		Table!1* pt = ptAddr.Data.Virtual.Ptr!(Table!1);

		return pt.Get(ptIdx);
	}

	void Install() {
		CPU_install_cr3(Root);
	}

	@property PhysAddress Root() {
		return rootPhys;
	}

	@property ref ulong RefCounter() {
		return refCounter;
	}

private:
	Table!4* root;
	PhysAddress rootPhys;
	ulong refCounter;
}

private extern (C) extern __gshared {
	ubyte PML4;
}

Paging GetKernelPaging() {
	import Data.Util : InplaceClass;

	__gshared ubyte[__traits(classInstanceSize, Paging)] data;
	__gshared Paging kernelPaging;

	if (!kernelPaging)
		kernelPaging = InplaceClass!Paging(data, &PML4);
	return kernelPaging;
}
