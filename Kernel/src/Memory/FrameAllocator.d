module Memory.FrameAllocator;

import Data.Address;
import IO.Log;
import Data.Linker;
import Data.Multiboot;

static struct FrameAllocator {
public:
	static void Init() {
		frameCount = Multiboot.memorySize / 0x1000;

		const ulong kernelUsedAmount = (Linker.KernelEnd - Linker.KernelStart).Int / 0x1000;
		for (ulong i = 0; i < kernelUsedAmount / 64 + 1; i++)
			bitmaps[i] = ulong.max;

		auto maps = Multiboot.MemoryMap;
		for (int i = 0; i < Multiboot.MemoryMapCount; i++) {
			auto m = maps[i];
			if (m.Type != MultibootMemoryType.Available)
				for (int j = 0; j < m.Length / 0x1000; j++)
					MarkFrame(m.Address / 0x1000 + j);
		}

		// Mark ACPI frames
		for (int i = 0xE0000; i < 0x100000; i += 0x1000)
			MarkFrame(i / 0x1000);

		foreach (mod; Multiboot.Modules[0 .. Multiboot.ModulesCount])
			for (int i = mod.ModStart; i < mod.ModEnd; i += 0x1000)
				MarkFrame(i / 0x1000);

		foreach (ref ulong frame; preallocated)
			frame = ulong.max;

		allocPreAlloc(); // Add some nodes to preallocated
	}

	static void MarkFrame(ulong idx) {
		foreach (ref ulong frame; preallocated)
			if (frame == idx) {
				frame = 0;
				return;
			}

		const ulong bitmapIdx = idx / 64;
		assert(bitmapIdx < bitmaps.length);
		const ulong bitIdx = idx % 64;

		bitmaps[bitmapIdx] |= (1 << bitIdx);
	}

	static ulong GetFrame() {
		foreach (idx, ref ulong frame; preallocated) {
			if (frame != ulong.max) {
				const ulong ret = frame;
				frame = ulong.max;
				return ret;
			}
		}

		allocPreAlloc();
		return GetFrame();
	}

	static void FreeFrame(ulong idx) {
		foreach (ref ulong frame; preallocated)
			if (frame == ulong.max) {
				frame = idx;
				return;
			}

		ulong bitmapIdx = idx / 64;
		assert(bitmapIdx < bitmaps.length);
		const ulong bitIdx = idx % 64;

		bitmaps[bitmapIdx] &= ~(1 << bitIdx);

		curBitmapIdx = bitmapIdx;
	}

	static PhysAddress Alloc() {
		return PhysAddress(GetFrame() << 12);
	}

	static void Free(PhysAddress memory) {
		FreeFrame(memory.Int / 0x1000);
	}

private:
	enum ulong maxmem = 0x10000000000 - 1; //pow(2, 40)

	__gshared ulong frameCount;
	__gshared ulong[((maxmem / 8) / 0x1000) / 64 + 1] bitmaps;
	__gshared ulong curBitmapIdx;
	__gshared ulong[64] preallocated;

	static void allocPreAlloc() {
		foreach (ref ulong frame; preallocated) {
			if (frame != ulong.max)
				continue;

			while (bitmaps[curBitmapIdx] == ulong.max && curBitmapIdx < bitmaps.length)
				curBitmapIdx++;

			if (curBitmapIdx == bitmaps.length)
				log.Fatal("No memory");

			ulong* bitmap = &bitmaps[curBitmapIdx];
			for (int i = 0; i < ulong.sizeof * 8; i++)
				if (!((*bitmap >> i) & 1)) {
					frame = curBitmapIdx * ulong.sizeof * 8 + i;
					*bitmap |= (1 << i);
					break;
				}
		}
	}
}
