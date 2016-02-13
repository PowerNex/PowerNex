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
				_memset64(PhysAddress(child.Data).Virtual.Ptr, 0, 0x1000); //Defined in object.d
			} else if (child.PageSize)
				log.Fatal("PageSize handling is not implemented!");

			return child;
		}
}

static assert(Table!4.sizeof == (ulong[512]).sizeof);

private extern (C) void CPU_install_cr3(PhysAddress addr);

struct Paging {
	Table!4* root;

	void Init() {
		root = cast(Table!4*)PhysAddress(FrameAllocator.Alloc()).Virtual.Ptr;
		_memset64(root, 0, 0x1000); //Defined in object.d
	}

	void InitWithPML4(void* pml4) {
		root = cast(Table!4*)pml4;
	}

	void Map(VirtAddress virt, PhysAddress phys, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) {
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
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		auto pdpAddr = root.Get(pml4Idx).Data;
		if (!pdpAddr)
			return;
		Table!3* pdp = cast(Table!3*)PhysAddress(pdpAddr).Virtual.Ptr;

		auto pdAddr = root.Get(pdpIdx).Data;
		if (!pdAddr)
			return;
		Table!2* pd = cast(Table!2*)PhysAddress(pdAddr).Virtual.Ptr;

		auto ptAddr = root.Get(pdIdx).Data;
		if (!ptAddr)
			return;
		Table!1* pt = cast(Table!1*)PhysAddress(ptAddr).Virtual.Ptr;

		TablePtr!void* page = pt.Get(ptIdx);

		page.Mode = MapMode.Empty;
		page.Data = null;
		page.Present = false;
	}

	void UnmapAndFree(VirtAddress virt) {
		const ulong virtAddr = virt.Int;
		const ushort pml4Idx = (virtAddr >> 39) & 0x1FF;
		const ushort pdpIdx = (virtAddr >> 30) & 0x1FF;
		const ushort pdIdx = (virtAddr >> 21) & 0x1FF;
		const ushort ptIdx = (virtAddr >> 12) & 0x1FF;

		auto pdpAddr = root.Get(pml4Idx);
		if (!pdpAddr.Present)
			return;
		Table!3* pdp = cast(Table!3*)PhysAddress(pdpAddr.Data).Virtual.Ptr;

		auto pdAddr = root.Get(pdpIdx);
		if (!pdAddr.Present)
			return;
		Table!2* pd = cast(Table!2*)PhysAddress(pdAddr.Data).Virtual.Ptr;

		auto ptAddr = root.Get(pdIdx);
		if (!ptAddr.Present)
			return;
		Table!1* pt = cast(Table!1*)PhysAddress(ptAddr.Data).Virtual.Ptr;

		TablePtr!void* page = pt.Get(ptIdx);

		FrameAllocator.Free(PhysAddress(page.data));

		page.Mode = MapMode.Empty;
		page.Data = null;
		page.Present = false;
	}

	void MapFreeMemory(VirtAddress virt, MapMode pageMode, MapMode tablesMode = MapMode.DefaultUser) {
		PhysAddress phys = FrameAllocator.Alloc();
		Map(virt, phys, pageMode, tablesMode);
		_memset64(virt.Ptr, 0, 0x1000); //Defined in object.d
	}

	void Install() {
		PhysAddress rootAddr = PhysAddress(root) - Linker.KernelStart.Int;
		CPU_install_cr3(rootAddr);
	}
}

private extern (C) extern __gshared {
	ubyte PML4;
}

Paging* GetKernelPaging() {
	__gshared Paging kernelPaging;
	__gshared bool initialized = false;

	if (!initialized) {
		kernelPaging.InitWithPML4(&PML4);
		initialized = true;
	}
	return &kernelPaging;
}
