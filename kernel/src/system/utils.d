module system.utils;

import data.address;
import task.scheduler;
import memory.paging;

bool isValidToRead(VirtAddress addr, ulong size) {
	while (size > 0) {
		auto page = (*getScheduler.currentProcess).threadState.paging.getPage(addr);
		if (!page || !page.present)
			return false;
		size -= 0x1000;
		addr += 0x1000;
	}
	return true;
}

bool isValidToWrite(VirtAddress addr, ulong size) {
	ulong counter = 0;
	while (size > counter) {
		auto page = (*getScheduler.currentProcess).threadState.paging.getPage(addr);
		if (!page || !page.present || !(page.mode & MapMode.writable))
			return false;
		counter += 0x1000;
		addr += 0x1000;
	}
	return true;
}
