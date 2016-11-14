module io.fs.io.console.virtualconsole;
import io.fs;
import io.fs.io.console;
import task.scheduler;
import task.process;

class VirtualConsole : Console {
public:
	this(VirtualConsoleScreen _vcs) {
		super();
		this._vcs = _vcs;
	}

	override bool open() {
		if (_inUse)
			return false;
		return _inUse = true;
	}

	override void close() {
		_inUse = false;
	}

	override ulong read(ubyte[] buffer, ulong offset) {
		size_t read;

		if (_kbStart == _kbEnd)
			getScheduler.waitFor(WaitReason.keyboard, cast(ulong)_kbBuffer.ptr);

		while (read < buffer.length && _kbStart != _kbEnd)
			buffer[read++] = _kbBuffer[_kbStart++];

		return read;
	}

	override ulong write(ubyte[] buffer, ulong offset) {
		return _vcs.write(buffer, offset);
	}

	bool addKeyboardInput(dchar ch) {
		import data.utf;

		if (_kbEnd + 1 == _kbStart)
			return false;

		size_t bytesUsed;
		ubyte[4] utf8 = toUTF8(ch, bytesUsed);

		//XXX: Make this prettier
		if ((bytesUsed > 1 && _kbEnd + 2 == _kbStart) || (bytesUsed > 2 && _kbEnd + 3 == _kbStart) || (bytesUsed > 3 && _kbEnd
				+ 4 == _kbStart))
			return false;
		foreach (b; utf8[0 .. bytesUsed])
			_kbBuffer[_kbEnd++] = b;

		getScheduler.wakeUp(WaitReason.keyboard, &_wakeUpKeyboard, cast(void*)_kbBuffer.ptr);
		return true;
	}

	@property bool active() {
		return _vcs.active;
	}

	@property bool active(bool active) {
		return _vcs.active = active;
	}

private:
	bool _inUse;
	VirtualConsoleScreen _vcs;
	size_t _kbStart;
	size_t _kbEnd;
	ubyte[0x1000] _kbBuffer;
	static bool _wakeUpKeyboard(Process* p, void* data) {
		return p.waitData == cast(ulong)data;
	}
}
