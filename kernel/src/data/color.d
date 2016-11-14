module data.color;

struct Color {
align(1):
	ubyte b;
	ubyte g;
	ubyte r;
	ubyte a;

	this(ubyte r, ubyte g, ubyte b) {
		this(r, g, b, 255);
	}

	this(ubyte r, ubyte g, ubyte b, ubyte a) {
		this.r = r;
		this.g = g;
		this.b = b;
		this.a = a;
	}

	this(uint color) {
		this.r = cast(ubyte)(color >> 24);
		this.g = cast(ubyte)(color >> 16);
		this.b = cast(ubyte)(color >> 8);
		this.a = cast(ubyte)(color >> 0);
	}

	Color opBinary(string op)(ubyte rhs) {
		return Color(cast(ubyte)(mixin("r" ~ op ~ "rhs")), cast(ubyte)(mixin("g" ~ op ~ "rhs")), cast(ubyte)(mixin("b" ~ op ~ "rhs")), a);
	}

	Color opOpAssign(string op)(ubyte rhs) {
		this = opBinary!op(rhs);
		return this;
	}

	bool opEquals(const Color o) const {
		return o.b == b && o.g == g && o.r == r && o.a == a;
	}
}

static assert(Color.sizeof == uint.sizeof);
