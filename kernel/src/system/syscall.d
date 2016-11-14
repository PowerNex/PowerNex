module system.syscall;

import data.address;
import data.string_;
import data.register;
import system.utils;
import task.scheduler : getScheduler;
import task.process;

enum SyscallID : ulong {
	nothing = 0,
	exit,
	clone,
	sleep,
	exec,
	getPermissions,
	getCurrentDirectory,
	changeCurrentDirectory,
	getPid,
	getParentPid,
	sendSignal,
	join,

	map,
	unmap,

	open,
	close,
	reOpen,
	read,
	write,

	createDirectory,
	removeDirectory,
	listDirectory,

	control,

	stats,
	duplicate,

	link,
	unlink,

	mount,
	unmount,

	changePermissions,
	changeOwner,

	updateSignalHandler,

	getTimestamp,
	getHostname,
	getUName,
	shutdown,

	//TODO: Remove these
	fork,
	yield,
	alloc,
	free,
	realloc,
	getArguments,
}

struct SyscallEntry {
	SyscallID id;
}

@SyscallEntry(SyscallID.exit)
void exit(long errorcode) {
	auto scheduler = getScheduler;
	scheduler.exit(errorcode);

	scheduler.currentProcess.syscallRegisters.rax = 0;
}

@SyscallEntry(SyscallID.clone)
void clone(ulong function(void*) func, VirtAddress stack, void* userdata, string name) {
	auto scheduler = getScheduler;
	getScheduler.currentProcess.syscallRegisters.rax = scheduler.clone(func, stack, userdata, name);
}

@SyscallEntry(SyscallID.fork)
void fork() {
	auto scheduler = getScheduler;

	scheduler.currentProcess.syscallRegisters.rax = scheduler.fork();
}

@SyscallEntry(SyscallID.sleep)
void sleep(ulong time) {
	auto scheduler = getScheduler;
	scheduler.uSleep(time);
	scheduler.currentProcess.syscallRegisters.rax = 0;
}

@SyscallEntry(SyscallID.exec)
void exec(string path, string[] args) {
	import io.fs.filenode;
	import data.elf : ELF;

	Process* process = getScheduler.currentProcess;

	FileNode file = cast(FileNode)process.currentDirectory.findNode(path);
	if (!file) {
		process.syscallRegisters.rax = 1;
		return;
	}

	ELF elf = new ELF(file);
	if (!elf.valid) {
		process.syscallRegisters.rax = 2;
		return;
	}

	elf.mapAndRun(args);
	assert(0);
}

@SyscallEntry(SyscallID.alloc)
void alloc(ulong size) {
	Process* process = getScheduler.currentProcess;
	process.syscallRegisters.rax = process.heap.alloc(size).VirtAddress;
}

@SyscallEntry(SyscallID.free)
void free(void* addr) {
	Process* process = getScheduler.currentProcess;
	process.heap.free(addr);
	process.syscallRegisters.rax = 0;
}

@SyscallEntry(SyscallID.realloc)
void realloc(void* addr, ulong newSize) {
	Process* process = getScheduler.currentProcess;
	process.syscallRegisters.rax = process.heap.realloc(addr, newSize).VirtAddress;
}

@SyscallEntry(SyscallID.getArguments)
void getArguments(ulong* argc, char*** argv) { //TODO: add Check for userspace pointer
	Process* process = getScheduler.currentProcess;
	if (!argc.VirtAddress.isValidToWrite(size_t.sizeof) || !argv.VirtAddress.isValidToWrite(const(char**).sizeof)) {
		process.syscallRegisters.rax = 1;
		return;
	}

	*argc = process.image.arguments.length - 1; // Don't count the null at the end
	*argv = process.image.arguments.ptr;
	process.syscallRegisters.rax = 0;
}

@SyscallEntry(SyscallID.open)
void open(string file) {
	import kmain : rootFS;
	import io.fs;

	Process* process = getScheduler.currentProcess;
	if (false && !(cast(void*)file.ptr).VirtAddress.isValidToRead(file.length)) {
		process.syscallRegisters.rax = 0;
		import io.log;

		log.warning("Failed to Read!");
		return;
	}

	FileNode node = cast(FileNode)rootFS.root.findNode(file);
	if (!node) {
		process.syscallRegisters.rax = 0;
		return;
	}
	node.open();

	auto id = process.fdCounter++;
	process.fileDescriptors.add(new FileDescriptor(id, node));
	process.syscallRegisters.rax = id;
}

@SyscallEntry(SyscallID.reOpen)
void reOpen(size_t id, string file) {
	import kmain : rootFS;
	import io.fs;

	Process* process = getScheduler.currentProcess;
	if (false && !(cast(void*)file.ptr).VirtAddress.isValidToRead(file.length)) {
		process.syscallRegisters.rax = 0;
		import io.log;

		log.warning("Failed to Read!");
		return;
	}

	for (size_t i = 0; i < process.fileDescriptors.length; i++) {
		FileDescriptor* item = process.fileDescriptors.get(i);
		if (item.id == id) {
			FileNode newNode = cast(FileNode)rootFS.root.findNode(file);
			if (!newNode) {
				process.syscallRegisters.rax = 1;
				return;
			}

			item.node.close();
			item.node = newNode;
			item.node.open();
			process.syscallRegisters.rax = 0;
			return;
		}
	}

	process.syscallRegisters.rax = 1;
}

@SyscallEntry(SyscallID.close)
void close(size_t id) {
	import kmain : rootFS;

	Process* process = getScheduler.currentProcess;

	for (size_t i = 0; i < process.fileDescriptors.length; i++) {
		FileDescriptor* item = process.fileDescriptors.get(i);
		if (item.id == id) {
			item.node.close();
			item.destroy;
			process.fileDescriptors.remove(i);
			process.syscallRegisters.rax = 0;
			return;
		}
	}

	process.syscallRegisters.rax = 1;
}

@SyscallEntry(SyscallID.write)
void write(size_t id, ubyte[] data, size_t offset) {
	import kmain : rootFS;

	Process* process = getScheduler.currentProcess;

	if (false && !data.ptr.VirtAddress.isValidToRead(data.length)) {
		process.syscallRegisters.rax = 0;
		import io.log;

		log.warning("Failed to Read!");
		return;
	}

	for (size_t i = 0; i < process.fileDescriptors.length; i++) {
		FileDescriptor* item = process.fileDescriptors.get(i);
		if (item.id == id) {
			process.syscallRegisters.rax = item.node.write(data, offset);
			return;
		}
	}

	process.syscallRegisters.rax = ulong.max;
}

@SyscallEntry(SyscallID.read)
void read(size_t id, ubyte[] data, size_t offset) {
	import kmain : rootFS;

	Process* process = getScheduler.currentProcess;

	if (false && !data.ptr.VirtAddress.isValidToWrite(data.length)) {
		process.syscallRegisters.rax = 0;
		import io.log;

		log.warning("Failed to Write!");
		return;
	}

	for (size_t i = 0; i < process.fileDescriptors.length; i++) {
		FileDescriptor* item = process.fileDescriptors.get(i);
		if (item.id == id) {
			process.syscallRegisters.rax = item.node.read(data, offset);
			return;
		}
	}

	process.syscallRegisters.rax = ulong.max;
}

@SyscallEntry(SyscallID.getTimestamp)
void getTimestamp() {
	import cpu.pit;
	import hw.cmos.cmos;

	Process* process = getScheduler.currentProcess;
	process.syscallRegisters.rax = getCMOS.timeStamp;
}

struct DirectoryListing {
	enum Type {
		unknown,
		file,
		directory
	}

	size_t id;
	char[256] name;
	Type type;
}

@SyscallEntry(SyscallID.listDirectory)
void listDirectory(void* listings_, size_t len) {
	import io.fs;

	DirectoryListing[] listings = (cast(DirectoryListing*)listings_)[0 .. len];

	Process* process = getScheduler.currentProcess;

	Node[] nodes = process.currentDirectory.nodes;
	auto length = nodes.length;
	if (listings.length < length)
		length = listings.length;
	foreach (i, ref DirectoryListing listing; listings[0 .. length]) {
		listing.id = nodes[i].id;
		auto nLen = nodes[i].name.length < 256 ? nodes[i].name.length : 256;
		memcpy(listing.name.ptr, nodes[i].name.ptr, nLen);
		if (nLen < 256)
			nLen++;
		listing.name[nLen - 1] = '\0';

		if (cast(FileNode)nodes[i])
			listing.type = DirectoryListing.Type.file;
		else if (cast(DirectoryNode)nodes[i])
			listing.type = DirectoryListing.Type.directory;
		else
			listing.type = DirectoryListing.Type.unknown;
	}

	process.syscallRegisters.rax = length;
}

@SyscallEntry(SyscallID.getCurrentDirectory)
void getCurrentDirectory(char[] str) {
	import io.fs;

	Process* process = getScheduler.currentProcess;
	size_t currentOffset = 0;

	void add(DirectoryNode node) {
		if (node.parent) {
			add(node.parent);

			auto len = 1 + node.name.length;
			if (str.length - currentOffset < len)
				len = str.length - currentOffset;

			str[currentOffset++] = '/';
			len--;
			memcpy(&str[currentOffset], node.name.ptr, len);
			currentOffset += len;
		}
	}

	add(process.currentDirectory);

	process.syscallRegisters.rax = currentOffset;
}

@SyscallEntry(SyscallID.changeCurrentDirectory)
void changeCurrentDirectory(string path) {
	import io.fs;

	Process* process = getScheduler.currentProcess;
	auto newDir = cast(DirectoryNode)process.currentDirectory.findNode(path);
	if (newDir) {
		process.currentDirectory = newDir;
		process.syscallRegisters.rax = 0;
	} else
		process.syscallRegisters.rax = 1;
}

@SyscallEntry(SyscallID.join)
void join(size_t pid) {
	import task.scheduler;

	Scheduler s = getScheduler;
	Process* process = s.currentProcess;
	process.syscallRegisters.rax = s.join(pid);
}
