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

	@property T* Data(T* address) {
		Address = PhysAddress(cast(ulong)address >> 12).Int;
		return Data();
	}

	@property T* Data() {
		return cast(T*)PhysAddress(Address << 12).Ptr;
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
		ChildType* child = &children[idx];
		static if (Level != 1)
			if (child.Present && child.PageSize)
				log.Fatal("PageSize handling is not implemented!");

		return child;
	}

	static if (Level != 1)
		ChildType* GetOrCreate(ushort idx, MapMode mode) {
			ChildType* child = &children[idx];

			if (!child.Present) {
				child.Data = cast(typeof(child.Data()))FrameAllocator.Alloc();
				child.Mode = mode;
				child.Present = true;
				_memset64(PhysAddress(child.Data).Virtual.Ptr, 0, 0x200); //Defined in object.d, 0x200 * 8 = 0x1000
			} else if (child.PageSize)
				log.Fatal("PageSize handling is not implemented!");

			return child;
		}
}

static assert(Table!4.sizeof == (ulong[512]).sizeof);

private extern (C) void CPU_install_cr3(PhysAddress addr);

class Paging {
	Table!4* root;

	this() {
		root = cast(Table!4*)PhysAddress(FrameAllocator.Alloc()).Virtual.Ptr;
		_memset64(root, 0, 0x200); //Defined in object.d
	}

	this(void* pml4) {
		root = cast(Table!4*)pml4;
	}

	void Map(VirtAddress virt, PhysAddress phys, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) {
		if (phys.Int == 0)
			return;
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		Table!3* pdp = cast(Table!3*)PhysAddress(root.GetOrCreate(pml4Idx, tablesMode).Data).Virtual.Ptr;
		Table!2* pd = cast(Table!2*)PhysAddress(pdp.GetOrCreate(pdpIdx, tablesMode).Data).Virtual.Ptr;
		Table!1* pt = cast(Table!1*)PhysAddress(pd.GetOrCreate(pdIdx, tablesMode).Data).Virtual.Ptr;
		TablePtr!void* page = pt.Get(ptIdx);

		page.Mode = pageMode;
		page.Data = phys.Ptr;
		page.Present = true;
	}

	void Unmap(VirtAddress virt) {
		auto page = GetPage(virt);
		if (!page)
			return;

		page.Mode = MapMode.Empty;
		page.Data = null;
		page.Present = false;
	}

	void UnmapAndFree(VirtAddress virt) {
		auto page = GetPage(virt);
		if (!page)
			return;

		FrameAllocator.Free(PhysAddress(page.Data));

		page.Mode = MapMode.Empty;
		page.Data = null;
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

	TablePtr!void* GetPage(VirtAddress virt) {
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
		Table!3* pdp = cast(Table!3*)PhysAddress(pdpAddr.Data).Virtual.Ptr;

		auto pdAddr = pdp.Get(pdpIdx);
		if (!pdAddr.Present)
			return null;
		Table!2* pd = cast(Table!2*)PhysAddress(pdAddr.Data).Virtual.Ptr;

		auto ptAddr = pd.Get(pdIdx);
		if (!ptAddr.Present)
			return null;
		Table!1* pt = cast(Table!1*)PhysAddress(ptAddr.Data).Virtual.Ptr;

		return pt.Get(ptIdx);
	}

	void Install() {
		auto page = GetPage(VirtAddress(root));
		if (page == null)
			log.Fatal("Paging address is not mapped!");
		PhysAddress rootAddr = PhysAddress(page.Data);
		CPU_install_cr3(rootAddr);
	}
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
