module System.Syscall;

import Data.Address;
import Data.String;
import Data.Register;
import System.Utils;
import Task.Scheduler : GetScheduler;
import Task.Process;

enum SyscallID : ulong {
	Nothing = 0,
	Exit,
	Clone,
	Sleep,
	Exec,
	GetPermissions,
	GetCurrentDirectory,
	ChangeCurrentDirectory,
	GetPid,
	GetParentPid,
	SendSignal,
	Join,

	Map,
	Unmap,

	Open,
	Close,
	ReOpen,
	Read,
	Write,

	CreateDirectory,
	RemoveDirectory,
	ListDirectory,

	Control,

	Stats,
	Duplicate,

	Link,
	Unlink,

	Mount,
	Unmount,

	ChangePermissions,
	ChangeOwner,

	UpdateSignalHandler,

	GetTimestamp,
	GetHostname,
	GetUName,
	Shutdown,

	//TODO: Remove these
	Fork,
	Yield,
	Alloc,
	Free,
	Realloc,
	GetArguments,
}

struct SyscallEntry {
	SyscallID id;
}

@SyscallEntry(SyscallID.Exit)
void Exit(long errorcode) {
	auto scheduler = GetScheduler;
	scheduler.Exit(errorcode);

	scheduler.CurrentProcess.syscallRegisters.RAX = 0;
}

@SyscallEntry(SyscallID.Clone)
void Clone(ulong function(void*) func, VirtAddress stack, void* userdata, string name) {
	auto scheduler = GetScheduler;
	GetScheduler.CurrentProcess.syscallRegisters.RAX = scheduler.Clone(func, stack, userdata, name);
}

@SyscallEntry(SyscallID.Fork)
void Fork() {
	auto scheduler = GetScheduler;

	scheduler.CurrentProcess.syscallRegisters.RAX = scheduler.Fork();
}

@SyscallEntry(SyscallID.Sleep)
void Sleep(ulong time) {
	auto scheduler = GetScheduler;
	scheduler.USleep(time);
	scheduler.CurrentProcess.syscallRegisters.RAX = 0;
}

@SyscallEntry(SyscallID.Exec)
void Exec(string path, string[] args) {
	import IO.FS.FileNode;
	import Data.ELF : ELF;

	Process* process = GetScheduler.CurrentProcess;

	FileNode file = cast(FileNode)process.currentDirectory.FindNode(path);
	if (!file) {
		process.syscallRegisters.RAX = 1;
		return;
	}

	ELF elf = new ELF(file);
	if (!elf.Valid) {
		process.syscallRegisters.RAX = 2;
		return;
	}

	elf.MapAndRun(args);
	assert(0);
}

@SyscallEntry(SyscallID.Alloc)
void Alloc(ulong size) {
	Process* process = GetScheduler.CurrentProcess;
	process.syscallRegisters.RAX = process.heap.Alloc(size).VirtAddress;
}

@SyscallEntry(SyscallID.Free)
void Free(void* addr) {
	Process* process = GetScheduler.CurrentProcess;
	process.heap.Free(addr);
	process.syscallRegisters.RAX = 0;
}

@SyscallEntry(SyscallID.Realloc)
void Realloc(void* addr, ulong newSize) {
	Process* process = GetScheduler.CurrentProcess;
	process.syscallRegisters.RAX = process.heap.Realloc(addr, newSize).VirtAddress;
}

@SyscallEntry(SyscallID.GetArguments)
void GetArguments(ulong* argc, char*** argv) { //TODO: add Check for userspace pointer
	Process* process = GetScheduler.CurrentProcess;
	if (!argc.VirtAddress.IsValidToWrite(size_t.sizeof) || !argv.VirtAddress.IsValidToWrite(const(char**).sizeof)) {
		process.syscallRegisters.RAX = 1;
		return;
	}

	*argc = process.image.arguments.length - 1; // Don't count the null at the end
	*argv = process.image.arguments.ptr;
	process.syscallRegisters.RAX = 0;
}

@SyscallEntry(SyscallID.Open)
void Open(string file) {
	import KMain : rootFS;
	import IO.FS;

	Process* process = GetScheduler.CurrentProcess;
	if (false && !(cast(void*)file.ptr).VirtAddress.IsValidToRead(file.length)) {
		process.syscallRegisters.RAX = 0;
		import IO.Log;

		log.Warning("Failed to Read!");
		return;
	}

	FileNode node = cast(FileNode)rootFS.Root.FindNode(file);
	if (!node) {
		process.syscallRegisters.RAX = 0;
		return;
	}
	node.Open();

	auto id = process.fdCounter++;
	process.fileDescriptors.Add(new FileDescriptor(id, node));
	process.syscallRegisters.RAX = id;
}

@SyscallEntry(SyscallID.ReOpen)
void ReOpen(size_t id, string file) {
	import KMain : rootFS;
	import IO.FS;

	Process* process = GetScheduler.CurrentProcess;
	if (false && !(cast(void*)file.ptr).VirtAddress.IsValidToRead(file.length)) {
		process.syscallRegisters.RAX = 0;
		import IO.Log;

		log.Warning("Failed to Read!");
		return;
	}

	for (size_t i = 0; i < process.fileDescriptors.Length; i++) {
		FileDescriptor* item = process.fileDescriptors.Get(i);
		if (item.id == id) {
			item.node.Close();

			item.node = cast(FileNode)rootFS.Root.FindNode(file);
			if (!item.node) {
				process.syscallRegisters.RAX = 1;
				return;
			}

			process.syscallRegisters.RAX = 0;
			return;
		}
	}
}

@SyscallEntry(SyscallID.Close)
void Close(size_t id) {
	import KMain : rootFS;

	Process* process = GetScheduler.CurrentProcess;

	for (size_t i = 0; i < process.fileDescriptors.Length; i++) {
		FileDescriptor* item = process.fileDescriptors.Get(i);
		if (item.id == id) {
			item.node.Close();
			item.destroy;
			process.fileDescriptors.Remove(i);
			process.syscallRegisters.RAX = 0;
			return;
		}
	}

	process.syscallRegisters.RAX = 1;
}

@SyscallEntry(SyscallID.Write)
void Write(size_t id, ubyte[] data, size_t offset) {
	import KMain : rootFS;

	Process* process = GetScheduler.CurrentProcess;

	if (false && !data.ptr.VirtAddress.IsValidToRead(data.length)) {
		process.syscallRegisters.RAX = 0;
		import IO.Log;

		log.Warning("Failed to Read!");
		return;
	}

	for (size_t i = 0; i < process.fileDescriptors.Length; i++) {
		FileDescriptor* item = process.fileDescriptors.Get(i);
		if (item.id == id) {
			process.syscallRegisters.RAX = item.node.Write(data, offset);
			return;
		}
	}

	process.syscallRegisters.RAX = ulong.max;
}

@SyscallEntry(SyscallID.Read)
void Read(size_t id, ubyte[] data, size_t offset) {
	import KMain : rootFS;

	Process* process = GetScheduler.CurrentProcess;

	if (false && !data.ptr.VirtAddress.IsValidToWrite(data.length)) {
		process.syscallRegisters.RAX = 0;
		import IO.Log;

		log.Warning("Failed to Write!");
		return;
	}

	for (size_t i = 0; i < process.fileDescriptors.Length; i++) {
		FileDescriptor* item = process.fileDescriptors.Get(i);
		if (item.id == id) {
			process.syscallRegisters.RAX = item.node.Read(data, offset);
			return;
		}
	}

	process.syscallRegisters.RAX = ulong.max;
}

@SyscallEntry(SyscallID.GetTimestamp)
void GetTimestamp() {
	import CPU.PIT;
	import HW.CMOS.CMOS;

	Process* process = GetScheduler.CurrentProcess;
	process.syscallRegisters.RAX = GetCMOS.TimeStamp;
}

struct DirectoryListing {
	enum Type {
		Unknown,
		File,
		Directory
	}

	size_t id;
	char[256] name;
	Type type;
}

@SyscallEntry(SyscallID.ListDirectory)
void ListDirectory(void* listings_, size_t len) {
	import IO.FS;

	DirectoryListing[] listings = (cast(DirectoryListing*)listings_)[0 .. len];

	Process* process = GetScheduler.CurrentProcess;

	Node[] nodes = process.currentDirectory.Nodes;
	auto length = nodes.length;
	if (listings.length < length)
		length = listings.length;
	foreach (i, ref DirectoryListing listing; listings[0 .. length]) {
		listing.id = nodes[i].ID;
		auto nLen = nodes[i].Name.length < 256 ? nodes[i].Name.length : 256;
		memcpy(listing.name.ptr, nodes[i].Name.ptr, nLen);
		if (nLen < 256)
			nLen++;
		listing.name[nLen - 1] = '\0';

		if (cast(FileNode)nodes[i])
			listing.type = DirectoryListing.Type.File;
		else if (cast(DirectoryNode)nodes[i])
			listing.type = DirectoryListing.Type.Directory;
		else
			listing.type = DirectoryListing.Type.Unknown;
	}

	process.syscallRegisters.RAX = length;
}

@SyscallEntry(SyscallID.GetCurrentDirectory)
void GetCurrentDirectory(char[] str) {
	import IO.FS;

	Process* process = GetScheduler.CurrentProcess;
	size_t currentOffset = 0;

	void add(DirectoryNode node) {
		if (node.Parent) {
			add(node.Parent);

			auto len = 1 + node.Name.length;
			if (str.length - currentOffset < len)
				len = str.length - currentOffset;

			str[currentOffset++] = '/';
			len--;
			memcpy(&str[currentOffset], node.Name.ptr, len);
			currentOffset += len;
		}
	}

	add(process.currentDirectory);

	process.syscallRegisters.RAX = currentOffset;
}

@SyscallEntry(SyscallID.ChangeCurrentDirectory)
void ChangeCurrentDirectory(string path) {
	import IO.FS;

	Process* process = GetScheduler.CurrentProcess;
	auto newDir = cast(DirectoryNode)process.currentDirectory.FindNode(path);
	if (newDir) {
		process.currentDirectory = newDir;
		process.syscallRegisters.RAX = 0;
	} else
		process.syscallRegisters.RAX = 1;
}

@SyscallEntry(SyscallID.Join)
void Join(size_t pid) {
	import Task.Scheduler;

	Scheduler s = GetScheduler;
	Process* process = s.CurrentProcess;
	process.syscallRegisters.RAX = s.Join(pid);
}
