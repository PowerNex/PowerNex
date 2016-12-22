module fs;

public {
	import fs.node;
}

import memory.ref_;

__gshared Ref!FileSystem mountedFS;

void initFS() {
	import fs.nullfs;
	import memory.allocator;

	mountedFS = cast(Ref!FileSystem)makeRef!NullFS(kernelAllocator);
}

Ref!VNode findNode(scope Ref!VNode startNode, in string path) {
	import data.string_ : indexOf;
	import io.log : log;

	Ref!VNode currentNode = startNode;
	string curPath = path;
	while (curPath.length && currentNode) {
		if (currentNode.type != NodeType.directory)
			return Ref!VNode();

		long partEnding = curPath.indexOf('/');
		string part;
		if (partEnding == -1) {
			part = curPath[0 .. $];
			curPath = curPath[$ .. $];
		} else {
			part = curPath[0 .. partEnding];
			if (curPath.length - 1 == partEnding)
				curPath = curPath[$ .. $];
			else
				curPath = curPath[partEnding + 1 .. $];
		}

		Ref!DirectoryEntryRange range;
		currentNode.dirEntries(range);

		bool foundit;
		foreach (DirectoryEntry e; range.data)
			if (e.name == part) {
				currentNode = currentNode.fs.getNode(e.id);
				foundit = true;
				break;
			}
		if (!foundit)
			return Ref!VNode();

		while (currentNode && currentNode.type == NodeType.symlink) {
			//TODO: implement infinite check
			string walkPath;
			currentNode.readLink(walkPath);
			currentNode = findNode(currentNode, walkPath);
		}

		if (!currentNode)
			return Ref!VNode();
	}
	return currentNode;
}
