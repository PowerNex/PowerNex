module System.Utils;

import Data.Address;
import Task.Scheduler;
import Memory.Paging;

bool IsValidToRead(VirtAddress addr, ulong size) {
	while (size > 0) {
		auto page = currentProcess.threadState.paging.GetPage(addr);
		if (!page || !page.Present)
			return false;
		size -= 0x1000;
		addr += 0x1000;
	}
	return true;
}

bool IsValidToWrite(VirtAddress addr, ulong size) {
	ulong counter = 0;
	while (size > counter) {
		auto page = currentProcess.threadState.paging.GetPage(addr);
		if (!page || !page.Present || !(page.Mode & MapMode.Writable))
			return false;
		counter += 0x1000;
		addr += 0x1000;
	}
	return true;
}
