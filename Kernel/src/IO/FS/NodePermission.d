module IO.FS.NodePermission;

enum Mask {
	None = 0,

	X = 1,
	W = 2,
	R = 4,

	RW = 6,
	RX = 5,
	WX = 3,
	RWX = 7
}

struct PermissionMask {
	private Mask data;

	this(Mask user, Mask group, Mask everyone) {
		data = cast(Mask)((user & 0x7) << 0x6 | (group & 0x7) << 0x3 | (everyone & 0x7) << 0x0);
	}

	@property Mask User() {
		return cast(Mask)((data >> 0x6) & 0x7);
	}

	@property void User(Mask val) {
		data = cast(Mask)((data & 0xfffffffffffffe3f) | ((val & 0x7) << 0x6));
	}

	@property Mask Group() {
		return cast(Mask)((data >> 0x3) & 0x7);
	}

	@property void Group(Mask val) {
		data = cast(Mask)((data & 0xffffffffffffffc7) | ((val & 0x7) << 0x3));
	}

	@property Mask Everyone() {
		return cast(Mask)((data >> 0x0) & 0x7);
	}

	@property void Everyone(Mask val) {
		data = cast(Mask)((data & 0xfffffffffffffff8) | ((val & 0x7) << 0x0));
	}
}

struct NodePermissions {
	PermissionMask mask;
	ulong user;
	ulong group;

	this(PermissionMask mask, ulong user, ulong group) {
		this.mask = mask;
		this.user = user;
		this.group = group;
	}
}
