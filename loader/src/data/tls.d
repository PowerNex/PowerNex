module data.tls;

import data.address;

@safe struct TLSData {
	TLSData* self;
	size_t size;
}

///
@safe static struct TLS {
public static:
	/// This is called from Multiboot2
	void init(VirtAddress tdataAddr, size_t tdataSize, VirtAddress tbssAddr, size_t tbssSize) @trusted {
		this.tdataAddr = tdataAddr;
		this.tdataSize = tdataSize;
		this.tbssAddr = tbssAddr;
		this.tbssSize = tbssSize;
	}

	///	Aquire a TLS context for the current thread
	void aquireTLS() @trusted {
		import io.log : Log;
		import memory.heap : Heap;

		// TODO: check allocation is 0x10 aligned!
		size_t size = tdataSize + tbssSize + TLSData.sizeof;
		VirtAddress data = Heap.allocate(size).VirtAddress;

		Log.info("Allocated tls section at: ", data);

		TLSData* tlsData = (data + size - TLSData.sizeof).ptr!TLSData;
		data.memcpy(tdataAddr, tdataSize);
		(data + tdataSize).memset(0, tbssSize);

		tlsData.self = tlsData;
		tlsData.size = size;

		{
			import arch.amd64.msr : MSR;

			MSR.fs = tlsData.VirtAddress;
		}
	}

private static:
	// The master copy
	__gshared VirtAddress tdataAddr;
	__gshared size_t tdataSize;
	__gshared VirtAddress tbssAddr;
	__gshared size_t tbssSize;
}
