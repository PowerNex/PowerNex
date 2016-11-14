module memory.frameallocator;

import data.address;
import io.log;
import data.linker;
import data.multiboot;

static struct FrameAllocator {
public:
	static void init() {
		_neverFreeBelow = PhysAddress((Linker.kernelEnd - Linker.kernelStart + Linker.kernelPhysStart.num).num);
		log.warning("_neverFreeBelow: ", _neverFreeBelow);

		_maxFrames = Multiboot.memorySize / 4;
		foreach (ref ulong frame; _preallocated)
			frame = ulong.max;

		const ulong kernelUsedAmount = _neverFreeBelow.num / 0x1000;
		for (ulong i = 0; i < (kernelUsedAmount / 64) + 1; i++) {
			_bitmaps[i] = ulong.max;
			_usedFrames += 64;
		}

		auto maps = Multiboot.memoryMap;
		for (ulong i = 0; i < Multiboot.memoryMapCount; i++) {
			auto m = maps[i];
			if (m.type != MultibootMemoryType.available) {
				log.debug_("Address: ", cast(void*)m.address, " Size: ", m.length, " Frames: ", m.length / 0x1000);
				for (ulong j = 0; j < m.length / 0x1000; j++)
					markFrame(m.address / 0x1000 + j);
			}
		}

		// Mark ACPI frames
		for (ulong i = 0xE0000; i < 0x100000; i += 0x1000)
			markFrame(i / 0x1000);

		foreach (mod; Multiboot.modules[0 .. Multiboot.modulesCount])
			for (ulong i = mod.modStart; i < mod.modEnd; i += 0x1000)
				markFrame(i / 0x1000);

		_allocPreAlloc(); // Add some nodes to _preallocated
	}

	static void markFrame(ulong idx) {
		foreach (ref ulong frame; _preallocated)
			if (frame == idx) {
				frame = ulong.max;
				return;
			}

		const ulong bitmapIdx = idx / 64;
		assert(bitmapIdx < _bitmaps.length);
		const ulong bitIdx = idx % 64;

		ulong* bitmap = &(_bitmaps[bitmapIdx]);

		if (!(*bitmap & (1UL << bitIdx))) {
			if (idx < _maxFrames)
				_usedFrames++;
			*bitmap |= (1UL << bitIdx);
		}
	}

	static ulong getFrame() {
		ulong getFrameImpl(bool tryAgain) {
			foreach (idx, ref ulong frame; _preallocated) {
				if (frame != ulong.max) {
					const ulong ret = frame;
					frame = ulong.max;
					return ret;
				}
			}

			if (tryAgain) {
				_allocPreAlloc();
				return getFrameImpl(false);
			}

			bool hasSpacePrealloc = false;

			foreach (ulong frame; _preallocated)
				hasSpacePrealloc |= frame != ulong.max;

			bool hasSpaceBitmap = false;

			for (ulong i = 0; i < _maxFrames && !hasSpaceBitmap; i++) {
				const ulong bitmapIdx = i / 64;
				assert(bitmapIdx < _bitmaps.length);
				const ulong bitIdx = i % 64;

				hasSpaceBitmap |= !(_bitmaps[bitmapIdx] & (1UL << bitIdx));
			}

			return 0;
		}

		return getFrameImpl(true);
	}

	static void freeFrame(ulong idx) {
		if (idx == 0)
			return;
		foreach (ref ulong frame; _preallocated)
			if (frame == ulong.max) {
				frame = idx;
				return;
			}

		ulong bitmapIdx = idx / 64;
		assert(bitmapIdx < _bitmaps.length);
		const ulong bitIdx = idx % 64;

		_bitmaps[bitmapIdx] &= ~(1UL << bitIdx);
		if (idx < _maxFrames)
			_usedFrames--;

		if (bitmapIdx < _currentBitmapIdx)
			_currentBitmapIdx = bitmapIdx;
	}

	static PhysAddress alloc() {
		return PhysAddress(getFrame() << 12);
	}

	/// Allocates 512 frames, returns the first one
	static PhysAddress alloc512() {
		ulong firstGood;
		ulong count;
		while (_currentBitmapIdx < _maxFrames) {
			if (_bitmaps[_currentBitmapIdx])
				count = 0;
			else
				count++;

			if (count == 1)
				firstGood = _currentBitmapIdx;
			else if (count == 8)
				break;

			_currentBitmapIdx++;
		}

		if (count < 8)
			return PhysAddress(0);

		foreach (idx; 0 .. 8)
			_bitmaps[firstGood + idx] = ulong.max;

		return PhysAddress((firstGood * 64) << 12);
	}

	static void free(PhysAddress memory) {
		if (memory > _neverFreeBelow)
			freeFrame(memory.num / 0x1000);
	}

	@property static ulong maxFrames() {
		return _maxFrames;
	}

	@property static ulong usedFrames() {
		return _usedFrames;
	}

private:
	enum ulong _maxmem = 0x100_0000_0000 - 1; //pow(2, 40)

	__gshared PhysAddress _neverFreeBelow;
	__gshared ulong _maxFrames;
	__gshared ulong _usedFrames;
	__gshared ulong[((_maxmem / 8) / 0x1000) / 64 + 1] _bitmaps;
	__gshared ulong _currentBitmapIdx;
	__gshared ulong[1] _preallocated;

	static void _allocPreAlloc() {
		bool reseted = false;
		foreach (ref ulong frame; _preallocated) {
			if (frame != ulong.max)
				continue;

			while (_bitmaps[_currentBitmapIdx] == ulong.max) {
				assert(_currentBitmapIdx < _bitmaps.length);
				if (_currentBitmapIdx != 0 && (_currentBitmapIdx - 1) * 64 >= _maxFrames) {
					if (reseted)
						return; // The error will be handled in getFrame()
					reseted = true;
					_currentBitmapIdx = 0;
				} else
					_currentBitmapIdx++;
			}

			ulong* bitmap = &(_bitmaps[_currentBitmapIdx]);
			for (ulong i = 0; i < 64; i++) {
				if (!(*bitmap & (1UL << i))) {
					const ulong frameID = _currentBitmapIdx * 64 + i;
					if (frameID < _maxFrames) {
						frame = frameID;
						*bitmap |= (1UL << i);
						_usedFrames++;
					}
					break;
				}
			}
		}
	}
}
