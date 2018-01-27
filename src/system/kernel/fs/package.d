module fs;

public {
	import fs.node;
}

import memory.ptr;

SharedPtr!VNode findNode(SharedPtr!VNode startNode, in string path) {
	import kmain: rootFS; //TODO:
	import stl.text : indexOf;
	import io.log : Log;

	if (path.length && path[0] == '/')
		return findNode((*rootFS).root, path[1 .. $]);

	SharedPtr!VNode currentNode = startNode;
	string curPath = path;
	while (curPath.length && currentNode) {
		if ((*currentNode).type != NodeType.directory)
			return SharedPtr!VNode();

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

		SharedPtr!DirectoryEntryRange range;
		assert((*currentNode).dirEntries(range) == IOStatus.success);

		bool foundit;
		foreach (DirectoryEntry e; range.get)
			if (e.name == part) {
				currentNode = e.fileSystem.getNode(e.id);
				foundit = true;
				break;
			}
		if (!foundit)
			return SharedPtr!VNode();

		while (currentNode && (*currentNode).type == NodeType.symlink) {
			//TODO: implement infinite check
			string walkPath;
			(*currentNode).readLink(walkPath);
			currentNode = findNode(currentNode, walkPath);
		}

		if (!currentNode)
			return SharedPtr!VNode();
	}
	return currentNode;
}

IOStatus read(T)(VNode node, ref NodeContext nc, T[] arr) {
	IOStatus result = node.read(nc, (cast(ubyte*)arr.ptr)[0 .. T.sizeof * arr.length]);
	return result;
}

IOStatus write(T)(VNode node, ref NodeContext nc, T[] obj) {
	IOStatus result = node.write(nc, (cast(ubyte*)arr.ptr)[0 .. T.sizeof * arr.length]);
	return result;
}

IOStatus read(T)(VNode node, ref NodeContext nc, T* obj) {
	IOStatus result = node.read(nc, (cast(ubyte*)obj)[0 .. T.sizeof]);
	//assert(result == T.sizeof);
	return result;
}

IOStatus write(T)(VNode node, ref NodeContext nc, T* obj) {
	IOStatus result = node.write(nc, (cast(ubyte*)obj)[0 .. T.sizeof]);
	//assert(result == T.sizeof);
	return result;
}

IOStatus read(T)(VNode node, ref NodeContext nc, ref T obj) {
	return .read(node, nc, &obj);
}

IOStatus write(T)(VNode node, ref NodeContext nc, ref T obj) {
	return .write(node, nc, &obj);
}
