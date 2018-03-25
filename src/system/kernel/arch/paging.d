module arch.paging;

import stl.vmm.paging;
import stl.vmm.vmm;

version (X86_64) {
	import arch.amd64.paging;
	import stl.address;

	alias Paging = AMD64Paging;

	private extern (C) ulong cpuRetCR3();
	void initKernelPaging() {
		import arch.amd64.paging : AMD64Paging;
		import stl.address : PhysAddress;

		PhysAddress pml4 = cpuRetCR3();
		_kernelPaging = AMD64Paging(pml4);
	}

	private __gshared AMD64Paging _kernelPaging;
	extern (C) AMD64Paging* getKernelPaging() @trusted {
		return &_kernelPaging;
	}

	extern (C) bool validAddress(VirtAddress vAddr) @trusted {
		return _kernelPaging.isValid(vAddr);
	}

	extern (C) VirtAddress mapSpecialAddress(PhysAddress pAddr, size_t size, bool readWrite = false, bool clear = false) @trusted {
		return _kernelPaging.mapSpecialAddress(pAddr, size, readWrite, clear);
	}

	extern (C) void unmapSpecialAddress(ref VirtAddress vAddr, size_t size) @trusted {
		_kernelPaging.unmapSpecialAddress(vAddr, size);
	}

	extern (C) bool mapAddress(VirtAddress vAddr, PhysAddress pAddr, VMPageFlags flags, bool clear = false) @trusted {
		return _kernelPaging.mapAddress(vAddr, pAddr, flags, clear);
	}

	extern (C) bool unmap(VirtAddress vAddr, bool freePage = false) @trusted {
		return _kernelPaging.unmap(vAddr, freePage);
	}
} else {
	static assert(0, "Paging is not implemented for the architecture!");
}
