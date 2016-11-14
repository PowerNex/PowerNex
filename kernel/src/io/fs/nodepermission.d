module io.fs.nodepermission;

enum Mask {
	none = 0,

	x = 1,
	w = 2,
	r = 4,

	rw = 6,
	rx = 5,
	wx = 3,
	rwx = 7
}

struct PermissionMask {
	private Mask _data;

	//TODO: Bitfield

	this(Mask user, Mask group, Mask everyone) {
		_data = cast(Mask)((user & 0x7) << 0x6 | (group & 0x7) << 0x3 | (everyone & 0x7) << 0x0);
	}

	@property Mask user() {
		return cast(Mask)((_data >> 0x6) & 0x7);
	}

	@property void user(Mask val) {
		_data = cast(Mask)((_data & 0xfffffffffffffe3f) | ((val & 0x7) << 0x6));
	}

	@property Mask group() {
		return cast(Mask)((_data >> 0x3) & 0x7);
	}

	@property void group(Mask val) {
		_data = cast(Mask)((_data & 0xffffffffffffffc7) | ((val & 0x7) << 0x3));
	}

	@property Mask everyone() {
		return cast(Mask)((_data >> 0x0) & 0x7);
	}

	@property void everyone(Mask val) {
		_data = cast(Mask)((_data & 0xfffffffffffffff8) | ((val & 0x7) << 0x0));
	}
}

struct NodePermissions {
	@property static NodePermissions defaultPermissions() {
		return NodePermissions(PermissionMask(Mask.rwx, Mask.rx, Mask.rx), 0UL, 0UL);
	}

	PermissionMask _mask;
	ulong _user;
	ulong _group;

	this(PermissionMask mask, ulong user, ulong group) {
		_mask = mask;
		_user = user;
		_group = group;
	}
}
