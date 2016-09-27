module IO.FS.IO.Console.VirtualConsole;
import IO.FS;
import IO.FS.IO.Console;
import Task.Scheduler;
import Task.Process;

class VirtualConsole : Console {
public:
	this(VirtualConsoleScreen vcs) {
		super();
		this.vcs = vcs;
	}

	override bool Open() {
		if (inUse)
			return false;
		return inUse = true;
	}

	override void Close() {
		inUse = false;
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		size_t read;

		if (kbStart == kbEnd)
			GetScheduler.WaitFor(WaitReason.Keyboard, cast(ulong)kbBuffer.ptr);

		while (read < buffer.length && kbStart != kbEnd)
			buffer[read++] = kbBuffer[kbStart++];

		return read;
	}

	override ulong Write(ubyte[] buffer, ulong offset) {
		return vcs.Write(buffer, offset);
	}

	bool AddKeyboardInput(dchar ch) {
		import Data.UTF;

		if (kbEnd + 1 == kbStart)
			return false;

		size_t bytesUsed;
		ubyte[4] utf8 = ToUTF8(ch, bytesUsed);

		//XXX: Make this prettier
		if ((bytesUsed > 1 && kbEnd + 2 == kbStart) || (bytesUsed > 2 && kbEnd + 3 == kbStart) || (bytesUsed > 3 && kbEnd + 4 == kbStart))
			return false;
		foreach (b; utf8[0 .. bytesUsed])
			kbBuffer[kbEnd++] = b;

		GetScheduler.WakeUp(WaitReason.Keyboard, &wakeUpKeyboard, cast(void*)kbBuffer.ptr);
		return true;
	}

	@property bool Active() {
		return vcs.Active;
	}

	@property bool Active(bool active) {
		return vcs.Active = active;
	}

private:
	bool inUse;
	VirtualConsoleScreen vcs;
	size_t kbStart;
	size_t kbEnd;
	ubyte[0x1000] kbBuffer;
	static bool wakeUpKeyboard(Process* p, void* data) {
		return p.waitData == cast(ulong)data;
	}
}
