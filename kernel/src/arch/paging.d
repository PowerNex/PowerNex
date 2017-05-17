module arch.paging;

version (X86_64) {
	public import arch.amd64.paging;
} else {
	static assert(0, "Paging is not implemented for the architecture!");
}

import memory.allocator;
import memory.ref_;

//TODO: Change to HWPaging, using hack to allocator class!
__gshared Ref!HWPaging hwPaging;
