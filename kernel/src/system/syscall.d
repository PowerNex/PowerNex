module system.syscall;

import data.address;
import data.string_;
import data.register;
import system.utils;
import task.process;
import data.container;
import memory.ptr;
import fs;
import io.log;
import memory.allocator;

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
	assert(0);
	/*auto scheduler = getScheduler;
	scheduler.exit(errorcode);

	(*scheduler.currentProcess).syscallRegisters.rax = 0;*/
}

@SyscallEntry(SyscallID.clone)
void clone(ulong function(void*) func, VirtAddress stack, void* userdata, string name) {
	assert(0);
	/*auto scheduler = getScheduler;
	(*scheduler.currentProcess).syscallRegisters.rax = scheduler.clone(func, stack, userdata, name);*/
}

@SyscallEntry(SyscallID.fork)
void fork() {
	assert(0);
	/*auto scheduler = getScheduler;

	(*scheduler.currentProcess).syscallRegisters.rax = scheduler.fork();*/
}

@SyscallEntry(SyscallID.sleep)
void sleep(ulong time) {
	assert(0);
	/*auto scheduler = getScheduler;
	scheduler.uSleep(time);
	(*scheduler.currentProcess).syscallRegisters.rax = 0;*/
}

@SyscallEntry(SyscallID.exec)
void exec(string path, string[] args) {
	assert(0);
	/*import data.elf : ELF;

	auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;

	SharedPtr!VNode file = (*process).currentDirectory.findNode(path);
	if (!file || (*file).type != NodeType.file) {
		(*process).syscallRegisters.rax = 1;
		return;
	}

	ELF elf = kernelAllocator.make!ELF(file);
	if (!elf.valid) {
		(*process).syscallRegisters.rax = 2;
		return;
	}

	elf.mapAndRun(args);
	log.fatal();*/
}

@SyscallEntry(SyscallID.alloc)
void alloc(ulong size) {
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	(*process).syscallRegisters.rax = (*(*process).allocator).allocate(size).VirtAddress;*/
}

@SyscallEntry(SyscallID.free)
void free(void[] addr) {
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	(*(*process).allocator).deallocate(addr); // Hack
	(*process).syscallRegisters.rax = 0;*/
}

@SyscallEntry(SyscallID.realloc)
void realloc(void[] addr, ulong newSize) {
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	(*process).syscallRegisters.rax = (*(*process).allocator).reallocate(addr, newSize).VirtAddress;*/
}

@SyscallEntry(SyscallID.getArguments)
void getArguments(ulong* argc, char*** argv) { //TODO: add Check for userspace pointer
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	if (!argc.VirtAddress.isValidToWrite(size_t.sizeof) || !argv.VirtAddress.isValidToWrite(const(char**).sizeof)) {
		(*process).syscallRegisters.rax = 1;
		return;
	}

	*argc = (*process).image.arguments.length - 1; // Don't count the null at the end
	*argv = (*process).image.arguments.ptr;
	(*process).syscallRegisters.rax = 0;*/
}

@SyscallEntry(SyscallID.open)
void open(string file, string modestr) {
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	if (false && !(cast(void*)file.ptr).VirtAddress.isValidToRead(file.length)) {
		(*process).syscallRegisters.rax = 0;
		import io.log;

		log.warning("Failed to Read!");
		return;
	}

	SharedPtr!VNode node = (*process).currentDirectory.findNode(file);
	if (!node) {
		(*process).syscallRegisters.rax = size_t.max;
		return;
	}
	SharedPtr!NodeContext nc = kernelAllocator.makeSharedPtr!NodeContext;

	FileDescriptorMode mode;
	foreach (char c; modestr) {
		switch (c) {
		case 'r':
			mode |= FileDescriptorMode.read;
			break;
		case 'w':
			mode |= FileDescriptorMode.write;
			break;
		case 'a':
			mode |= FileDescriptorMode.append;
			break;
		case 'c':
			mode |= FileDescriptorMode.create;
			break;
		case 'd':
			mode |= FileDescriptorMode.direct;
			break;
		case 'b':
			mode |= FileDescriptorMode.binary;
			break;
		default:
			break;
		}
	}

	if ((*node).open(**nc, mode) != IOStatus.success) {
		(*process).syscallRegisters.rax = size_t.max;
		return;
	}

	auto id = (*process).fdIDCounter++;
	(*(*process).fileDescriptors)[id] = nc;
	(*process).syscallRegisters.rax = id;*/
}

@SyscallEntry(SyscallID.close)
void close(size_t id) {
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;

	Nullable!(SharedPtr!NodeContext) nc = (*(*process).fileDescriptors).get(id);

	if (nc.isNull) {
		(*process).syscallRegisters.rax = ulong.max;
		return;
	}

	(*nc.get).close();
	(*process).syscallRegisters.rax = !(*(*process).fileDescriptors).remove(id);*/
}

@SyscallEntry(SyscallID.write)
void write(size_t id, ubyte[] data, size_t offset) { //TODO: remove offset
	assert(0);
	/*import kmain : rootFS;

	auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;

	if (false && !data.ptr.VirtAddress.isValidToRead(data.length)) {
		(*process).syscallRegisters.rax = 0;
		import io.log;

		log.warning("Failed to Read!");
		return;
	}

	Nullable!(SharedPtr!NodeContext) node = (*(*process).fileDescriptors).get(id);
	if (!node.isNull) {
		(*node.get).offset = offset;
		(*process).syscallRegisters.rax = (*node.get).write(data);
	} else
		(*process).syscallRegisters.rax = ulong.max;*/
}

@SyscallEntry(SyscallID.read)
void read(size_t id, ubyte[] data, size_t offset) {
	assert(0);
	/*import kmain : rootFS;

	auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;

	if (false && !data.ptr.VirtAddress.isValidToWrite(data.length)) {
		(*process).syscallRegisters.rax = 0;
		import io.log;

		log.warning("Failed to Write!");
		return;
	}

	Nullable!(SharedPtr!NodeContext) node = (*(*process).fileDescriptors).get(id);
	if (!node.isNull) {
		(*node.get).offset = offset;
		(*process).syscallRegisters.rax = (*node.get).read(data);
	} else
		(*process).syscallRegisters.rax = ulong.max;*/
}

@SyscallEntry(SyscallID.getTimestamp)
void getTimestamp() {
	assert(0);
	/*import cpu.pit;
	import hw.cmos.cmos;

	auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	(*process).syscallRegisters.rax = getCMOS.timeStamp;*/
}

struct DirectoryListing {
	enum Type { //TODO: Keep in sync with NodeType
		file,
		directory,
		fifo,
		socket,
		symlink,
		hardlink,
		chardevice, // For example a TTY
		blockdevice // HDD
	}

	char[256] name;
	Type type;
}

@SyscallEntry(SyscallID.listDirectory)
void listDirectory(string path, DirectoryListing[] listings, size_t start) {
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;

	SharedPtr!VNode cwd = (*process).currentDirectory;

	if (path) {
		SharedPtr!VNode newDir = cwd.findNode(path);
		if (!newDir || (*newDir).type != NodeType.directory) {
			log.error();
			(*process).syscallRegisters.rax = size_t.max;
			return;
		}
		cwd = newDir;
	}

	SharedPtr!DirectoryEntryRange range;
	if ((*cwd).dirEntries(range) != IOStatus.success) {
		log.error();
		(*process).syscallRegisters.rax = size_t.max;
		return;
	}

	if (!listings) {
		size_t len;
		while (!(*range).empty()) {
			len++;
			(*range).popFront();
		}

		log.warning();
		(*process).syscallRegisters.rax = len;
		return;
	}

	while (start && start-- && !(*range).empty)
		(*range).popFront(); //TODO: optimize

	if (start) {
		log.warning();
		(*process).syscallRegisters.rax = 0;
		return;
	}

	size_t length = 0;
	foreach (idx, DirectoryEntry entry; *range) {
		if (idx >= listings.length)
			break;
		with (listings[idx]) {
			auto len = entry.name.length < 256 ? entry.name.length : 256;
			memcpy(name.ptr, entry.name.ptr, len);
			if (len < 256)
				len++;
			name[len - 1] = '\0';

			if (auto _ = entry.fileSystem.getNode(entry.id))
				type = cast(Type)(*_).type; //TODO: make sure
			else
				type = Type.file; //TODO: add error
		}
		length++;
	}

	(*process).syscallRegisters.rax = length;*/
}

@SyscallEntry(SyscallID.getCurrentDirectory)
void getCurrentDirectory(char[] str) {
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	size_t currentOffset = 0;

	void add(SharedPtr!VNode node) {
		if ((*node).type != NodeType.directory) {
			str[currentOffset .. currentOffset + 6] = "/<ERR0>"[];
			return;
		}
		SharedPtr!VNode parent = node.findNode("..");
		if (parent && node != parent) {
			add(parent);

			SharedPtr!DirectoryEntryRange range;
			if ((*parent).dirEntries(range) != IOStatus.success) {
				str[currentOffset .. currentOffset + 6] = "/<ERR1>"[];
				return;
			}

			string name = "<ERR2>";
			foreach (DirectoryEntry de; *range)
				if (de.id == (*node).id) {
					name = de.name;
					break;
				}

			auto len = 1 + name.length;
			if (str.length - currentOffset < len)
				len = str.length - currentOffset;

			str[currentOffset++] = '/';
			len--;
			memcpy(&str[currentOffset], name.ptr, len);
			currentOffset += len;
		}
	}

	add((*process).currentDirectory);

	(*process).syscallRegisters.rax = currentOffset;*/
}

@SyscallEntry(SyscallID.changeCurrentDirectory)
void changeCurrentDirectory(string path) {
	assert(0);
	/*auto scheduler = getScheduler;

	SharedPtr!Process process = scheduler.currentProcess;
	SharedPtr!VNode newDir = (*process).currentDirectory.findNode(path);
	if (newDir) {
		(*process).currentDirectory = newDir;
		(*process).syscallRegisters.rax = 0;
	} else
		(*process).syscallRegisters.rax = 1;*/
}

@SyscallEntry(SyscallID.join)
void join(size_t pid) {
	assert(0);
	/*import task.scheduler;

	Scheduler s = getScheduler;
	SharedPtr!Process process = s.currentProcess;
	(*process).syscallRegisters.rax = s.join(pid);*/
}
