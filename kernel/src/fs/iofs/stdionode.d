module fs.iofs.stdionode;

import fs;
import memory.ptr;

final class StdIONode : VNode {
public:
	this(FileSystem fs, FSNodeID id, FSNodeID parent) {
		this.id = id;
		this.type = NodeType.chardevice;
		this.fs = fs;
		this.mode = makeMode(7, 7, 5);

		this.name = "StdIO";
	}

	bool addKeyboardInput(dchar ch) {
		import task.scheduler;
		import data.utf;

		if (kbEnd + 1 == kbStart)
			return false;

		size_t bytesUsed;
		ubyte[4] utf8 = toUTF8(ch, bytesUsed);

		//XXX: Make this prettier
		if ((bytesUsed > 1 && kbEnd + 2 == kbStart) || (bytesUsed > 2 && kbEnd + 3 == kbStart) || (bytesUsed > 3 && kbEnd + 4 == kbStart))
			return false;
		foreach (b; utf8[0 .. bytesUsed])
			kbBuffer[kbEnd++] = b;

		//getScheduler.wakeUp(WaitReason.keyboard, &wakeUpKeyboard, cast(void*)kbBuffer.ptr);
		return true;
	}

	override IOStatus chmod(ushort mode) {
		this.mode = mode;
		return IOStatus.success;
	}

	override IOStatus chown(long uid, long gid) {
		this.uid = uid;
		this.gid = gid;
		return IOStatus.success;
	}

	override IOStatus link(in string name, SharedPtr!VNode node) {
		return -IOStatus.isNotDirectory;
	}

	override IOStatus unlink(in string name) {
		return -IOStatus.isNotDirectory;
	}

	override IOStatus readLink(out string path) {
		return -IOStatus.isNotSymlink;
	}

	override IOStatus mount(in string name, SharedPtr!FileSystem filesystem) {
		return -IOStatus.isNotDirectory;
	}

	override IOStatus umount(in string name) {
		return -IOStatus.isNotDirectory;
	}

	override IOStatus open(out NodeContext fd, FileDescriptorMode mode) {
		fd = NodeContext(this, 0);
		return IOStatus.success;
	}

	override IOStatus close(in NodeContext fd) {
		return IOStatus.success;
	}

	override IOStatus read(ref NodeContext fd, ubyte[] buffer) {
		import task.scheduler;

		ssize_t read;

		if (kbStart == kbEnd)
			return -IOStatus.notFound;//getScheduler.waitFor(WaitReason.keyboard, cast(ulong)kbBuffer.ptr);

		while (read < buffer.length && kbStart != kbEnd)
			buffer[read++] = kbBuffer[kbStart++];

		return cast(IOStatus)read;
	}

	override IOStatus write(ref NodeContext fd, in ubyte[] buffer) {
		import data.textbuffer : scr = getBootTTY;
		import io.log : log;

		scr.write(cast(char[])buffer);
		return cast(IOStatus)buffer.length;
	}

	override IOStatus duplicate(ref NodeContext fd, out NodeContext copy) {
		copy = fd;
		return IOStatus.success;
	}

	override IOStatus dirEntries(out SharedPtr!DirectoryEntryRange entriesRange) {
		return -IOStatus.isNotDirectory;
	}

	override IOStatus mkdir(in string name, ushort mode) {
		return -IOStatus.isNotDirectory;
	}

	override IOStatus rmdir(in string name) {
		return -IOStatus.isNotDirectory;
	}

	override IOStatus ioctl(in NodeContext fd, size_t key, size_t value) {
		return IOStatus.success;
	}

	override IOStatus accept(in NodeContext fd, out NodeContext client) {
		return -IOStatus.isNotSocket;
	}

private:
	import task.process;

	size_t kbStart;
	size_t kbEnd;
	ubyte[128] kbBuffer;
	static bool wakeUpKeyboard(Process* p, void* data) {
		return p.waitData == cast(ulong)data;
	}
}
