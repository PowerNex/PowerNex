module arch.paging;

version (X86_64) {
	import arch.amd64.paging;
	import stl.address;

	alias Paging = AMD64Paging;

	private extern (C) ulong cpuRetCR3();
	void initKernelPaging() {
		import arch.amd64.paging : AMD64Paging;
		import stl.address : PhysAddress;

		__gshared PhysAddress pml4 = cpuRetCR3();
		_kernelPaging = AMD64Paging(pml4);
	}

	private __gshared AMD64Paging _kernelPaging;
	extern (C) AMD64Paging* getKernelPaging() @trusted {
		return &_kernelPaging;
	}

	extern (C) VirtAddress mapSpecialAddress(PhysAddress pAddr, size_t size, bool readWrite = false, bool clear = false) @trusted {
		_kernelPaging.mapSpecialAddress(pAddr, size, readWrite, clear);
	}

	extern (C) void unmapSpecialAddress(ref VirtAddress vAddr, size_t size) @trusted {
		_kernelPaging.unmapSpecialAddress(vAddr, size);
	}
} else {
	static assert(0, "Paging is not implemented for the architecture!");
}
