module memory.paging;

import data.address;
import data.bitfield;
import memory.frameallocator;
import io.log;
import linker;

enum MapMode : ulong { // TODO: Implement the rest.
	Present = 1 << 0,
	Writable = 1 << 1,
	User = 1 << 2,
	NotExecutable = 1UL << 63,

	Empty = 0,
	DefaultKernel = Present | Writable,
	DefaultUser = Present | User | Writable
}

struct TablePtr(T) {
	ulong data;

	@property T* Data(T* address) {
		Address = cast(ulong)PhysAddress(cast(ulong)address >> 12).Int;
		return Data();
	}

	@property T* Data() {
		return cast(T*)PhysAddress(Address << 12).Ptr;
	}

	@property MapMode Mode(MapMode mode) {
		ReadWrite = !!(mode & MapMode.Writable);
		User = !!(mode & MapMode.User);
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
		return &children[idx];
	}

	static if (Level != 1)
	ChildType* GetOrCreate(ushort idx, MapMode mode) {
		ChildType* child = &children[idx];

		if (!child.Present) {
			child.Data = cast(typeof(child.Data()))FrameAllocator.Alloc();
			child.Mode = mode;
			child.Present = true;
			_memset64((VirtAddress(child.Data) + Linker.KernelStart).Ptr, 0, 0x1000); //Defined in object.d
		}

		return child;
	}
}

static assert(Table!4.sizeof == (ulong[512]).sizeof);

private extern(C) void CPU_install_cr3(PhysAddress addr);

struct Paging {
	Table!4* root;

	void Init() {
		root = cast(Table!4*)(FrameAllocator.Alloc() + Linker.KernelStart).Ptr;
		_memset64(root, 0, 0x1000); //Defined in object.d
	}

	void Map(VirtAddress virt, PhysAddress phys, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) {
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		Table!3* pdp = cast(Table!3 *)(VirtAddress(root.GetOrCreate(pml4Idx, tablesMode).Data) + Linker.KernelStart).Ptr;
		Table!2* pd = cast(Table!2 *)(VirtAddress(pdp.GetOrCreate(pdpIdx, tablesMode).Data) + Linker.KernelStart).Ptr;
		Table!1* pt = cast(Table!1 *)(VirtAddress(pd.GetOrCreate(pdIdx, tablesMode).Data) + Linker.KernelStart).Ptr;
		TablePtr!void* page = pt.Get(ptIdx);

		page.Mode = pageMode;
		page.Data = phys.Ptr;
		page.Present = true;
	}

	void Unmap(VirtAddress virt) {
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		Table!3* pdp = cast(Table!3 *)(VirtAddress(root.Get(pml4Idx).Data) + Linker.KernelStart).Ptr;
		if (pdp == Linker.KernelStart.Ptr)
			return;
		Table!2* pd = cast(Table!2 *)(VirtAddress(pdp.Get(pdpIdx).Data) + Linker.KernelStart).Ptr;
		if (pd == Linker.KernelStart.Ptr)
			return;
		Table!1* pt = cast(Table!1 *)(VirtAddress(pd.Get(pdIdx).Data) + Linker.KernelStart).Ptr;
		if (pt == Linker.KernelStart.Ptr)
			return;
		TablePtr!void* page = pt.Get(ptIdx);

		page.Mode = MapMode.Empty;
		page.Data = null;
		page.Present = false;
	}

	void MapFreeMemory(VirtAddress virt, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) {
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		Table!3* pdp = cast(Table!3 *)(VirtAddress(root.GetOrCreate(pml4Idx, tablesMode).Data) + Linker.KernelStart).Ptr;
		Table!2* pd = cast(Table!2 *)(VirtAddress(pdp.GetOrCreate(pdpIdx, tablesMode).Data) + Linker.KernelStart).Ptr;
		Table!1* pt = cast(Table!1 *)(VirtAddress(pd.GetOrCreate(pdIdx, tablesMode).Data) + Linker.KernelStart).Ptr;
		TablePtr!void* page = pt.Get(ptIdx);

		page.Mode = pageMode;
		page.Data = FrameAllocator.Alloc();
		page.Present = true;
	}

	void Install() {
		PhysAddress rootAddr = PhysAddress(root) - Linker.KernelStart.Int;
		CPU_install_cr3(rootAddr);
	}
}

ref Paging GetKernelPaging() {
	__gshared Paging kernelPaging;
	__gshared bool initialized = false;

	if (!initialized) {
		kernelPaging.Init();

		enum ulong end = 0x4000000; // 64MiB

		for (PhysAddress cur = 0; cur.Int < end; cur += 0x1000)
			kernelPaging.Map(VirtAddress(cur) + Linker.KernelStart, cur, MapMode.DefaultUser);

		initialized = true;
	}
	return kernelPaging;
}
