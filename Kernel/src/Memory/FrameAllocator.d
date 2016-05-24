module Memory.FrameAllocator;

import Data.Address;
import IO.Log;
import Data.Linker;
import Data.Multiboot;

static struct FrameAllocator {
public:
	static void Init() {
		maxFrames = Multiboot.MemorySize / 4;
		foreach (ref ulong frame; preallocated)
			frame = ulong.max;

		const ulong kernelUsedAmount = (Linker.KernelEnd - Linker.KernelStart + Linker.KernelPhysStart.Int).Int / 0x1000;
		for (ulong i = 0; i < (kernelUsedAmount / 64) + 1; i++) {
			bitmaps[i] = ulong.max;
			usedFrames += 64;
		}

		auto maps = Multiboot.MemoryMap;
		for (ulong i = 0; i < Multiboot.MemoryMapCount; i++) {
			auto m = maps[i];
			if (m.Type != MultibootMemoryType.Available) {
				log.Debug("Address: ", cast(void*)m.Address, " Size: ", m.Length, " Frames: ", m.Length / 0x1000);
				for (ulong j = 0; j < m.Length / 0x1000; j++)
					MarkFrame(m.Address / 0x1000 + j);
			}
		}

		// Mark ACPI frames
		for (ulong i = 0xE0000; i < 0x100000; i += 0x1000)
			MarkFrame(i / 0x1000);

		foreach (mod; Multiboot.Modules[0 .. Multiboot.ModulesCount])
			for (ulong i = mod.ModStart; i < mod.ModEnd; i += 0x1000)
				MarkFrame(i / 0x1000);

		allocPreAlloc(); // Add some nodes to preallocated
	}

	static void MarkFrame(ulong idx) {
		foreach (ref ulong frame; preallocated)
			if (frame == idx) {
				frame = ulong.max;
				return;
			}

		const ulong bitmapIdx = idx / 64;
		assert(bitmapIdx < bitmaps.length);
		const ulong bitIdx = idx % 64;

		ulong* bitmap = &(bitmaps[bitmapIdx]);

		if (!(*bitmap & (1UL << bitIdx))) {
			if (idx < maxFrames)
				usedFrames++;
			*bitmap |= (1UL << bitIdx);
		}
	}

	static ulong GetFrame() {
		ulong getFrame(bool tryAgain) {
			foreach (idx, ref ulong frame; preallocated) {
				if (frame != ulong.max) {
					const ulong ret = frame;
					frame = ulong.max;
					return ret;
				}
			}

			if (tryAgain) {
				allocPreAlloc();
				return getFrame(false);
			}

			bool hasSpacePrealloc = false;

			foreach (ulong frame; preallocated)
				hasSpacePrealloc |= frame != ulong.max;

			bool hasSpaceBitmap = false;

			for (ulong i = 0; i < maxFrames && !hasSpaceBitmap; i++) {
				const ulong bitmapIdx = i / 64;
				assert(bitmapIdx < bitmaps.length);
				const ulong bitIdx = i % 64;

				hasSpaceBitmap |= !(bitmaps[bitmapIdx] & (1UL << bitIdx));
			}

			return 0;
		}

		return getFrame(true);
	}

	static void FreeFrame(ulong idx) {
		if (idx == 0)
			return;
		foreach (ref ulong frame; preallocated)
			if (frame == ulong.max) {
				frame = idx;
				return;
			}

		ulong bitmapIdx = idx / 64;
		assert(bitmapIdx < bitmaps.length);
		const ulong bitIdx = idx % 64;

		bitmaps[bitmapIdx] &= ~(1UL << bitIdx);
		if (idx < maxFrames)
			usedFrames--;

		if (bitmapIdx < currentBitmapIdx)
			currentBitmapIdx = bitmapIdx;
	}

	static PhysAddress Alloc() {
		return PhysAddress(GetFrame() << 12);
	}

	static void Free(PhysAddress memory) {
		FreeFrame(memory.Int / 0x1000);
	}

	@property static ulong MaxFrames() {
		return maxFrames;
	}

	@property static ulong UsedFrames() {
		return usedFrames;
	}

private:
	enum ulong maxmem = 0x100_0000_0000 - 1; //pow(2, 40)

	__gshared ulong maxFrames;
	__gshared ulong usedFrames;
	__gshared ulong[((maxmem / 8) / 0x1000) / 64 + 1] bitmaps;
	__gshared ulong currentBitmapIdx;
	__gshared ulong[1] preallocated;

	static void allocPreAlloc() {
		bool reseted = false;
		foreach (ref ulong frame; preallocated) {
			if (frame != ulong.max)
				continue;

			while (bitmaps[currentBitmapIdx] == ulong.max) {
				assert(currentBitmapIdx < bitmaps.length);
				if (currentBitmapIdx != 0 && (currentBitmapIdx - 1) * 64 >= maxFrames) {
					if (reseted)
						return; // The error will be handled in GetFrame()
					reseted = true;
					currentBitmapIdx = 0;
				} else
					currentBitmapIdx++;
			}

			ulong* bitmap = &(bitmaps[currentBitmapIdx]);
			for (ulong i = 0; i < 64; i++) {
				if (!(*bitmap & (1UL << i))) {
					const ulong frameID = currentBitmapIdx * 64 + i;
					if (frameID < maxFrames) {
						frame = frameID;
						*bitmap |= (1UL << i);
						usedFrames++;
					}
					break;
				}
			}
		}
	}
}
