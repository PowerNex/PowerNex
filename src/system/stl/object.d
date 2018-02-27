// PowerNexOS runtime
// Based on object.d in druntime
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file BOOST-LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

module object;

import stl.trait : isVersion;

static assert(isVersion!"PowerNex", "\x1B[31;1m\n\n
+--------------------------------------- ERROR ---------------------------------------+
|                                                                                     |
|  You need to follow the build steps that are specified inside the README.org file!  |
|                                                                                     |
+-------------------------------------------------------------------------------------+
\n\n\x1B[0m");

version (X86_64) {
	alias size_t = ulong;
	alias ptrdiff_t = long;
	alias string = immutable(char)[]; // TODO: Create wrapper for strings
}

class Object {
	string toString() {
		return typeid(this).name;
	}

	nothrow size_t toHash() @trusted {
		return cast(size_t)cast(void*)this;
	}

	int opCmp(Object o) {
		return cast(int)(cast(size_t)cast(void*)this - cast(size_t)cast(void*)o);
	}

	bool opEquals(Object o) {
		return this is typeid(o);
	}

	static Object factory(string classname) {
		return null;
	}
}

auto opEquals(const Object lhs, const Object rhs) {
	if (lhs is null && rhs is null)
		return true;
	if (lhs is null || rhs is null)
		return false;

	return lhs.opEquals(rhs);
}

bool __equals(T1, T2)(T1[] lhs, T2[] rhs) {
	import stl.trait : Unqual;

	alias RealT1 = Unqual!T1;
	alias RealT2 = Unqual!T2;

	static if (is(RealT1 == RealT2) && is(RealT1 == void)) {
		auto lhs_ = cast(ubyte[])lhs;
		auto rhs_ = cast(ubyte[])rhs;
		if (lhs_.length != rhs_.length)
			return false;
		foreach (idx, a; lhs_)
			if (a != rhs_[idx])
				return false;
		return true;
	} else static if (is(RealT1 == RealT2)) {
		if (lhs.length != rhs.length)
			return false;
		foreach (idx, a; lhs)
			if (a != rhs[idx])
				return false;
		return true;
	} else static if (__traits(compiles, { RealT2 a; auto b = cast(RealT1)a; }())) {
		if (lhs.length != rhs.length)
			return false;
		foreach (idx, a; lhs)
			if (a != cast(RealT1)rhs[idx])
				return false;
		return true;

	} else {
		pragma(msg, "I don't know what to do!: ", __PRETTY_FUNCTION__);
		assert(0, "I don't know what to do!");
	}
}

void __switch_error()(string file = __FILE__, size_t line = __LINE__) {
	assert(0, "Final switch fallthough! " ~ __PRETTY_FUNCTION__);
}

struct Interface {
	TypeInfo_Class classinfo;
	size_t offset;
}

struct OffsetTypeInfo {
	size_t offset;
	TypeInfo ti;
}

abstract class TypeInfo {
	override string toString() const pure @safe nothrow {
		return typeid(this).name;
	}

	override size_t toHash() @trusted const nothrow {
		size_t hash;
		foreach (ch; toString())
			hash = ch + (hash << 6) + (hash << 16) - hash;
		return hash;
	}

	override int opCmp(Object o) {
		import stl.address : memcmp;

		if (this is o)
			return 0;
		TypeInfo ti = cast(TypeInfo)o;
		if (ti is null)
			return 1;

		auto a = toString();
		auto b = ti.toString();
		if (a.length != b.length)
			return a.length - b.length;
		return memcmp(this.a, b, a.length);
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto ti = cast(const TypeInfo)o;
		return ti && this.toString() == ti.toString();
	}

	size_t getHash(in void* p) @trusted nothrow const {
		return cast(size_t)p;
	}

	bool equals(in void* p1, in void* p2) const {
		return p1 == p2;
	}

	int compare(in void* p1, in void* p2) const {
		return _xopCmp(p1, p2);
	}

	@property size_t tsize() nothrow pure const @safe @nogc {
		return 0;
	}

	void swap(void* p1, void* p2) const {
		immutable size_t n = tsize;
		for (size_t i = 0; i < n; i++) {
			byte t = (cast(byte*)p1)[i];
			(cast(byte*)p1)[i] = (cast(byte*)p2)[i];
			(cast(byte*)p2)[i] = t;
		}
	}

	@property inout(TypeInfo) next() nothrow pure inout @nogc {
		return null;
	}

	abstract const(void)[] initializer() nothrow pure const @safe @nogc;

	@property uint flags() nothrow pure const @safe @nogc {
		return 0;
	}

	const(OffsetTypeInfo)[] offTi() const {
		return null;
	}

	void destroy(void* p) const {
	}

	void postblit(void* p) const {
	}

	@property size_t talign() nothrow pure const @safe {
		return tsize;
	}

	version (X86_64) int argTypes(out TypeInfo arg1, out TypeInfo arg2) @safe nothrow {
		arg1 = this;
		return 0;
	}

	@property immutable(void)* rtInfo() nothrow pure const @safe @nogc {
		return null;
	}
}

class TypeInfo_Struct : TypeInfo {
	override string toString() const {
		return name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto s = cast(const TypeInfo_Struct)o;
		return s && this.name == s.name && this.initializer().length == s.initializer().length;
	}

	override size_t getHash(in void* p) @trusted pure nothrow const {
		assert(p);
		if (xtoHash) {
			return (*xtoHash)(p);
		} else {
			import core.internal.traits : externDFunc;

			alias hashOf = externDFunc!("rt.util.hash.hashOf", size_t function(const(void)[], size_t) @trusted pure nothrow @nogc);
			return hashOf(p[0 .. initializer().length], 0);
		}
	}

	override bool equals(in void* p1, in void* p2) @trusted pure nothrow const {
		import core.stdc.string : memcmp;

		if (!p1 || !p2)
			return false;
		else if (xopEquals)
			return (*xopEquals)(p1, p2);
		else if (p1 == p2)
			return true;
		else // BUG: relies on the GC not moving objects
			return memcmp(p1, p2, initializer().length) == 0;
	}

	override int compare(in void* p1, in void* p2) @trusted pure nothrow const {
		import core.stdc.string : memcmp;

		// Regard null references as always being "less than"
		if (p1 != p2) {
			if (p1) {
				if (!p2)
					return true;
				else if (xopCmp)
					return (*xopCmp)(p2, p1);
				else // BUG: relies on the GC not moving objects
					return memcmp(p1, p2, initializer().length);
			} else
				return -1;
		}
		return 0;
	}

	override @property size_t tsize() nothrow pure const {
		return initializer().length;
	}

	override const(void)[] initializer() nothrow pure const @safe {
		return m_init;
	}

	override @property uint flags() nothrow pure const {
		return m_flags;
	}

	override @property size_t talign() nothrow pure const {
		return m_align;
	}

	final override void destroy(void* p) const {
		if (xdtor) {
			if (m_flags & StructFlags.isDynamicType)
				(*xdtorti)(p, this);
			else
				(*xdtor)(p);
		}
	}

	override void postblit(void* p) const {
		if (xpostblit)
			(*xpostblit)(p);
	}

	string name;
	void[] m_init; // initializer; m_init.ptr == null if 0 initialize

	@safe pure nothrow {
		size_t function(in void*) xtoHash;
		bool function(in void*, in void*) xopEquals;
		int function(in void*, in void*) xopCmp;
		string function(in void*) xtoString;

		enum StructFlags : uint {
			hasPointers = 0x1,
			isDynamicType = 0x2, // built at runtime, needs type info in xdtor
		}

		StructFlags m_flags;
	}
	union {
		void function(void*) xdtor;
		void function(void*, const TypeInfo_Struct ti) xdtorti;
	}

	void function(void*) xpostblit;

	uint m_align;

	override @property immutable(void)* rtInfo() const {
		return m_RTInfo;
	}

	version (X86_64) {
		override int argTypes(out TypeInfo arg1, out TypeInfo arg2) {
			arg1 = m_arg1;
			arg2 = m_arg2;
			return 0;
		}

		TypeInfo m_arg1;
		TypeInfo m_arg2;
	}
	immutable(void)* m_RTInfo; // data for precise GC
}

class TypeInfo_Class : TypeInfo {
	override string toString() const {
		return info.name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_Class)o;
		return c && this.info.name == c.info.name;
	}

	override size_t getHash(in void* p) @trusted const {
		auto o = *cast(Object*)p;
		return o ? o.toHash() : 0;
	}

	override bool equals(in void* p1, in void* p2) const {
		Object o1 = *cast(Object*)p1;
		Object o2 = *cast(Object*)p2;

		return (o1 is o2) || (o1 && o1.opEquals(o2));
	}

	override int compare(in void* p1, in void* p2) const {
		Object o1 = *cast(Object*)p1;
		Object o2 = *cast(Object*)p2;
		int c = 0;

		// Regard null references as always being "less than"
		if (o1 !is o2) {
			if (o1) {
				if (!o2)
					c = 1;
				else
					c = o1.opCmp(o2);
			} else
				c = -1;
		}
		return c;
	}

	override @property size_t tsize() nothrow pure const {
		return Object.sizeof;
	}

	override const(void)[] initializer() nothrow pure const @safe {
		return m_init;
	}

	override @property uint flags() nothrow pure const {
		return 1;
	}

	override @property const(OffsetTypeInfo)[] offTi() nothrow pure const {
		return m_offTi;
	}

	@property auto info() @safe nothrow pure const {
		return this;
	}

	@property auto typeinfo() @safe nothrow pure const {
		return this;
	}

	byte[] m_init; /** class static initializer
                                 * (init.length gives size in bytes of class)
                                 */
	string name; /// class name
	void*[] vtbl; /// virtual function pointer table
	Interface[] interfaces; /// interfaces this class implements
	TypeInfo_Class base; /// base class
	void* destructor;
	void function(Object) classInvariant;
	enum ClassFlags : uint {
		isCOMclass = 0x1,
		noPointers = 0x2,
		hasOffTi = 0x4,
		hasCtor = 0x8,
		hasGetMembers = 0x10,
		hasTypeInfo = 0x20,
		isAbstract = 0x40,
		isCPPclass = 0x80,
		hasDtor = 0x100,
	}

	ClassFlags m_flags;
	void* deallocator;
	OffsetTypeInfo[] m_offTi;
	void function(Object) defaultConstructor; // default Constructor

	immutable(void)* m_RTInfo; // data for precise GC
	override @property immutable(void)* rtInfo() const {
		return m_RTInfo;
	}

	static const(TypeInfo_Class) find(in char[] classname) {
		return null;
	}

	Object create() const {
		return null;
	}
}

alias ClassInfo = TypeInfo_Class;
