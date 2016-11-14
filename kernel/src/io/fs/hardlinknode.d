module IO.FS.HardLinkNode;

import IO.FS;

class HardLinkNode : Node {
public:
	this(NodePermissions permission, ulong target) {
		super(permission);
		this.target = target;
	}

	@property ref ulong TargetID() {
		return target;
	}

	@property Node Target() {
		return root.GetNode(target);
	}

	@property Node Target(Node node) {
		if (node)
			target = node.ID;
		else
			target = ulong.max;

		return node;
	}

private:
	ulong target;
}
