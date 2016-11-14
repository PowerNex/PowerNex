module io.fs.hardlinknode;

import io.fs;

class HardLinkNode : Node {
public:
	this(NodePermissions permission, ulong target) {
		super(permission);
		_target = target;
	}

	@property ref ulong targetID() {
		return _target;
	}

	@property Node target() {
		return root.getNode(_target);
	}

	@property Node target(Node node) {
		if (node)
			_target = node.id;
		else
			_target = ulong.max;

		return node;
	}

private:
	ulong _target;
}
