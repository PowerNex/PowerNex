module object;

/**
 * Functions and object specifications are from: https://dlang.org/phobos/object.html
 */

///
template from(string moduleName) {
	mixin("import from = " ~ moduleName ~ ";");
}

alias string = immutable(char)[];
alias size_t = ulong;
alias hash_t = size_t;

///
enum {
	MIctorstart = 0x1, // we've started constructing it
	MIctordone = 0x2, // finished construction
	MIstandalone = 0x4, // module ctor does not depend on other module
	// ctors being done first
	MItlsctor = 8,
	MItlsdtor = 0x10,
	MIctor = 0x20,
	MIdtor = 0x40,
	MIxgetMembers = 0x80,
	MIictor = 0x100,
	MIunitTest = 0x200,
	MIimportedModules = 0x400,
	MIlocalClasses = 0x800,
	MIname = 0x1000,
}

///
struct ModuleInfo {
	uint _flags; ///
	uint _index; /// index into _moduleinfo_array[]

	@disable this();
	@disable this(this) const;

const:
	private void* addrOf(int flag) nothrow pure
	in {
		assert(flag >= MItlsctor && flag <= MIname);
		assert(!(flag & (flag - 1)) && !(flag & ~(flag - 1) << 1));
	}
	body {
		void* p = cast(void*)&this + ModuleInfo.sizeof;

		if (flags & MItlsctor) {
			if (flag == MItlsctor)
				return p;
			p += typeof(tlsctor).sizeof;
		}
		if (flags & MItlsdtor) {
			if (flag == MItlsdtor)
				return p;
			p += typeof(tlsdtor).sizeof;
		}
		if (flags & MIctor) {
			if (flag == MIctor)
				return p;
			p += typeof(ctor).sizeof;
		}
		if (flags & MIdtor) {
			if (flag == MIdtor)
				return p;
			p += typeof(dtor).sizeof;
		}
		if (flags & MIxgetMembers) {
			if (flag == MIxgetMembers)
				return p;
			p += typeof(xgetMembers).sizeof;
		}
		if (flags & MIictor) {
			if (flag == MIictor)
				return p;
			p += typeof(ictor).sizeof;
		}
		if (flags & MIunitTest) {
			if (flag == MIunitTest)
				return p;
			p += typeof(unitTest).sizeof;
		}
		if (flags & MIimportedModules) {
			if (flag == MIimportedModules)
				return p;
			p += size_t.sizeof + *cast(size_t*)p * typeof(importedModules[0]).sizeof;
		}
		if (flags & MIlocalClasses) {
			if (flag == MIlocalClasses)
				return p;
			p += size_t.sizeof + *cast(size_t*)p * typeof(localClasses[0]).sizeof;
		}
		if (true || flags & MIname) // always available for now
		{
			import utils : strlen;

			if (flag == MIname)
				return p;
			p += strlen(cast(immutable char*)p);
		}
		assert(0);
	}

	@property uint index() nothrow pure {
		return _index;
	}

	@property uint flags() nothrow pure {
		return _flags;
	}

	@property void function() tlsctor() nothrow pure {
		return flags & MItlsctor ? *cast(typeof(return)*)addrOf(MItlsctor) : null;
	}

	@property void function() tlsdtor() nothrow pure {
		return flags & MItlsdtor ? *cast(typeof(return)*)addrOf(MItlsdtor) : null;
	}

	@property void* xgetMembers() nothrow pure {
		return flags & MIxgetMembers ? *cast(typeof(return)*)addrOf(MIxgetMembers) : null;
	}

	@property void function() ctor() nothrow pure {
		return flags & MIctor ? *cast(typeof(return)*)addrOf(MIctor) : null;
	}

	@property void function() dtor() nothrow pure {
		return flags & MIdtor ? *cast(typeof(return)*)addrOf(MIdtor) : null;
	}

	@property void function() ictor() nothrow pure {
		return flags & MIictor ? *cast(typeof(return)*)addrOf(MIictor) : null;
	}

	@property void function() unitTest() nothrow pure {
		return flags & MIunitTest ? *cast(typeof(return)*)addrOf(MIunitTest) : null;
	}

	@property immutable(ModuleInfo*)[] importedModules() nothrow pure {
		if (flags & MIimportedModules) {
			auto p = cast(size_t*)addrOf(MIimportedModules);
			return (cast(immutable(ModuleInfo*)*)(p + 1))[0 .. *p];
		}
		return null;
	}

	@property TypeInfo_Class[] localClasses() nothrow pure {
		if (flags & MIlocalClasses) {
			auto p = cast(size_t*)addrOf(MIlocalClasses);
			return (cast(TypeInfo_Class*)(p + 1))[0 .. *p];
		}
		return null;
	}

	@property string name() nothrow pure {
		if (true || flags & MIname) // always available for now
		{
			import utils : strlen;

			auto p = cast(immutable char*)addrOf(MIname);
			return p[0 .. strlen(p)];
		}
		// return null;
	}

	alias extern (D) int delegate(ref ModuleInfo*) ApplyDg;

	static int opApply(scope ApplyDg dg) {
		ModuleInfo** start;
		ModuleInfo** end;

		// needed a linker hack here, commends see below
		start = cast(ModuleInfo**)&_minfo_beg;
		end = cast(ModuleInfo**)&_minfo_end;

		while (start != end) {
			auto m = *start;
			if (m !is null) {
				if (auto res = dg(m))
					return res;
			}
			start++;
		}
		return 0;
	}
}

/// All D class objects inherit from Object.
class Object {
	/// Convert Object to a human readable string.
	string toString() {
		return typeid(this).name;
	}

	/// Compute hash function for Object.
	size_t toHash() @trusted nothrow {
		return cast(size_t)cast(void*)this;
	}

	/// Compare with another Object obj.
	int opCmp(Object o) {
		size_t a = cast(size_t)cast(void*)this;
		size_t b = cast(size_t)cast(void*)o;

		if (a < b)
			return -1;
		else if (a == b)
			return 0;
		else
			return 1;
	}

	/// Test whether this is equal to o. The default implementation only compares by identity (using the is operator).
	/// Generally, overrides for opEquals should attempt to compare objects by their contents.
	bool opEquals(Object o) {
		return this is o;
	}

	interface Monitor {
		void lock();
		void unlock();
	}

	/** Create instance of class specified by the fully qualified name classname.
	 * The class must either have no constructors or have a default constructor.
	 *
	 * Note:
	 *   Will always return null!
	 */
	static Object factory(string classname) {
		assert(0);
	}
}

/// Returns true if lhs and rhs are equal.
auto opEquals(Object lhs, Object rhs) {
	if (lhs is rhs)
		return true;

	if (typeid(lhs) is typeid(rhs))
		return lhs.opEquals(rhs);

	return lhs.opEquals(rhs) && rhs.opEquals(lhs);
}

auto opEquals(const Object lhs, const Object rhs) {
	return opEquals(cast()lhs, cast()rhs);
}

/// Information about an interface. When an object is accessed via an interface, an Interface* appears as the first entry in its vtbl.
struct Interface {
	TypeInfo_Class classinfo; /// .classinfo for this interface (not for containing class)
	void*[] vtbl; /// virtual function pointer table
	size_t offset; /// offset to Interface 'this' from Object 'this'
}

/// Array of pairs giving the offset and type information for each member in an aggregate.
struct OffsetTypeInfo {
	size_t offset; // Offset of member from start of object
	TypeInfo ti; //TypeInfo for this member
}

/// Runtime type information about a type. Can be retrieved for any type using a TypeidExpression.
abstract class TypeInfo {
	override string toString() @safe pure nothrow const {
		return typeid(this).name;
	}

	override size_t toHash() @trusted nothrow const {
		return cast(size_t)typeid(this).name.ptr;
	}

	override int opCmp(Object o) {
		if (this is o)
			return 0;

		if (o is null)
			return 1;

		return toString() == (cast(TypeInfo)o).toString();
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;

		return o && toString() == (cast(TypeInfo)o).toString();
	}

	/// Computes a hash of the instance of a type.
	size_t getHash(in void* p) @trusted nothrow const {
		return cast(size_t)p;
	}

	/// Compares two instances for equality.
	bool equals(in void* p1, in void* p2) const {
		return p1 == p2;
	}

	/// Compares two instances for <, ==, or >.
	int compare(in void* p1, in void* p2) const {
		if (p1 < p2)
			return -1;
		else if (p1 > p2)
			return 1;
		else
			return 0;
	}

	/// Returns size of the type.
	@property size_t tsize() @safe @nogc pure nothrow const {
		return 0;
	}

	/// Swaps two instances of the type.
	void swap(void* p1, void* p2) const {
		size_t size = tsize;
		ubyte* b1 = cast(ubyte*)p1;
		ubyte* b2 = cast(ubyte*)p2;

		while (size--) {
			ubyte tmp = *b1;
			*b1 = *b2;
			*b2 = tmp;
			b1++;
			b2++;
		}
	}

	/// Get TypeInfo for 'next' type, as defined by what kind of type this is, null if none.
	@property inout(TypeInfo) next() @nogc pure nothrow inout {
		return null;
	}

	/// Return default initializer. If the type should be initialized to all zeros, an array with a null ptr and a length
	/// equal to the type size will be returned. For static arrays, this returns the default initializer for a single
	/// element of the array, use tsize to get the correct size.
	abstract const(void)[] initializer() @safe @nogc pure nothrow const;

	/// Get flags for type: 1 means GC should scan for pointers, 2 means arg of this type is passed in XMM register
	@property uint flags() @safe @nogc pure nothrow const {
		return 0;
	}

	/// Get type information on the contents of the type; null if not available
	const(OffsetTypeInfo)[] offTi() const {
		return null;
	}

	/// Run the destructor on the object and all its sub-objects
	void destroy(void* p) const {
	}

	/// Run the postblit on the object and all its sub-objects
	void postblit(void* p) const {
	}

	/// Return alignment of type
	@nogc @property @safe size_t talign() pure nothrow const {
		return tsize;
	}

	/// Return internal info on arguments fitting into 8byte. See X86-64 ABI 3.2.3
	version (X86_64) @safe int argTypes(out TypeInfo arg1, out TypeInfo arg2) nothrow {
		arg1 = this;
		return 0;
	}

	/// Return info used by the garbage collector to do precise collection.
	@property immutable(void)* rtInfo() @safe @nogc pure nothrow const {
		return null;
	}
}

/// Runtime type information about a class. Can be retrieved from an object instance by using the .classinfo property.
class TypeInfo_Class : TypeInfo {
	override string toString() const {
		return name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_Class)o;
		return c && name == c.name;
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

	byte[] m_init; /// class static initializer (init.length gives size in bytes of class)
	string name; /// class name
	void*[] vtbl; /// virtual function pointer table
	Interface[] interfaces; /// interfaces this class implements
	TypeInfo_Class base; /// base class

	void* destructor; ///
	void function(Object) classInvariant; ///
	///
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

	ClassFlags m_flags; ///
	void* deallocator; ///
	OffsetTypeInfo[] m_offTi; ///
	void function(Object) defaultConstructor; /// default Constructor

	immutable(void)* m_RTInfo; /// data for precise GC
	override @property immutable(void)* rtInfo() const {
		return m_RTInfo;
	}

	/// Search all modules for TypeInfo_Class corresponding to classname.
	static const(TypeInfo_Class) find(in char[] classname) {
		return null;
	}

	/// Create instance of Object represented by 'this'.
	Object create() const {
		return null;
	}
}

alias TypeInfo_Class ClassInfo;

class TypeInfo_AssociativeArray : TypeInfo {
	override string toString() const {
		return "(AA)UNK[UNK]";
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_AssociativeArray)o;
		return c && this.key == c.key && this.value == c.value;
	}

	override bool equals(in void* p1, in void* p2) @trusted const {
		return false; //!!_aaEqual(this, *cast(const void**)p1, *cast(const void**)p2);
	}

	override hash_t getHash(in void* p) nothrow @trusted const {
		return cast(hash_t)p; //_aaGetHash(cast(void*)p, this);
	}

	// BUG: need to add the rest of the functions

	override @property size_t tsize() nothrow pure const {
		return (char[int]).sizeof;
	}

	override const(void)[] initializer() const @trusted {
		return (cast(void*)null)[0 .. (char[int]).sizeof];
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return value;
	}

	override @property uint flags() nothrow pure const {
		return 1;
	}

	TypeInfo value; ///
	TypeInfo key; ///

	override @property size_t talign() nothrow pure const {
		return (char[int]).alignof;
	}
}

class TypeInfo_Function : TypeInfo {
	TypeInfo next; ///
	string deco; ///
}

class TypeInfo_Interface : TypeInfo {
	override string toString() const {
		return info.name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_Interface)o;
		return c && info.name == typeid(c).name;
	}

	override size_t getHash(in void* p) @trusted const {
		Interface* pi = **cast(Interface***)*cast(void**)p;
		Object o = cast(Object)(*cast(void**)p - pi.offset);
		assert(o);
		return o.toHash();
	}

	override bool equals(in void* p1, in void* p2) const {
		Interface* pi = **cast(Interface***)*cast(void**)p1;
		Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
		pi = **cast(Interface***)*cast(void**)p2;
		Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);

		return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
	}

	override int compare(in void* p1, in void* p2) const {
		Interface* pi = **cast(Interface***)*cast(void**)p1;
		Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
		pi = **cast(Interface***)*cast(void**)p2;
		Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);
		int c = 0;

		if (o1 != o2) {
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

	override const(void)[] initializer() const @trusted {
		return (cast(void*)null)[0 .. Object.sizeof];
	}

	override @property uint flags() nothrow pure const {
		return 1;
	}

	TypeInfo_Class info; ///
}

class TypeInfo_Struct : TypeInfo {
	override string toString() const {
		return name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto s = cast(const TypeInfo_Struct)o;
		return s && name == s.name && initializer.length == s.initializer.length;
	}

	override size_t getHash(in void* p) @trusted pure nothrow const {
		if (xtoHash)
			return (*xtoHash)(p);
		else
			return cast(size_t)p;
	}

	override bool equals(in void* p1, in void* p2) @trusted pure nothrow const {
		import utils : memcmp;

		if (!p1 || !p2)
			return false;
		else if (xopEquals)
			return (*xopEquals)(p1, p2);
		else if (p1 == p2)
			return true;
		else
			return memcmp(p1, p2, initializer.length) == 0;
	}

	override int compare(in void* p1, in void* p2) @trusted pure nothrow const {
		import utils : memcmp;

		if (p1 != p2) {
			if (p1) {
				if (!p2)
					return true;
				else if (xopCmp)
					return (*xopCmp)(p2, p1);
				else
					return memcmp(p1, p2, initializer.length);
			} else
				return -1;
		}
		return 0;
	}

	override @property size_t tsize() nothrow pure const {
		return initializer.length;
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

	string name; ///
	void[] m_init; /// initializer; m_init.ptr == null if 0 initialize

	@safe pure nothrow {
		size_t function(in void*) xtoHash; ///
		bool function(in void*, in void*) xopEquals; ///
		int function(in void*, in void*) xopCmp; ///
		string function(in void*) xtoString; ///

		///
		enum StructFlags : uint {
			hasPointers = 0x1,
			isDynamicType = 0x2, // built at runtime, needs type info in xdtor
		}

		StructFlags m_flags; ///
	}
	///
	union {
		void function(void*) xdtor; ///
		void function(void*, const TypeInfo_Struct ti) xdtorti; ///
	}

	void function(void*) xpostblit; ///

	uint m_align; ///

	///
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
	immutable(void)* m_RTInfo; /// data for precise GC
}

class TypeInfo_Pointer : TypeInfo {
	override string toString() const {
		return "UNK*";
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_Pointer)o;
		return c && this.m_next == c.m_next;
	}

	override size_t getHash(in void* p) @trusted const {
		return cast(size_t)*cast(void**)p;
	}

	override bool equals(in void* p1, in void* p2) const {
		return *cast(void**)p1 == *cast(void**)p2;
	}

	override int compare(in void* p1, in void* p2) const {
		if (*cast(void**)p1 < *cast(void**)p2)
			return -1;
		else if (*cast(void**)p1 > *cast(void**)p2)
			return 1;
		else
			return 0;
	}

	override @property size_t tsize() nothrow pure const {
		return (void*).sizeof;
	}

	override const(void)[] initializer() const @trusted {
		return (cast(void*)null)[0 .. (void*).sizeof];
	}

	override void swap(void* p1, void* p2) const {
		void* tmp = *cast(void**)p1;
		*cast(void**)p1 = *cast(void**)p2;
		*cast(void**)p2 = tmp;
	}

	override @property inout(TypeInfo) next() nothrow pure inout {
		return m_next;
	}

	override @property uint flags() nothrow pure const {
		return 1;
	}

	TypeInfo m_next; ///
}

class TypeInfo_Typedef : TypeInfo {
	override string toString() const {
		return name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_Typedef)o;
		return c && this.name == c.name && this.base == c.base;
	}

	override size_t getHash(in void* p) const {
		return base.getHash(p);
	}

	override bool equals(in void* p1, in void* p2) const {
		return base.equals(p1, p2);
	}

	override int compare(in void* p1, in void* p2) const {
		return base.compare(p1, p2);
	}

	override @property size_t tsize() nothrow pure const {
		return base.tsize;
	}

	override void swap(void* p1, void* p2) const {
		return base.swap(p1, p2);
	}

	override @property inout(TypeInfo) next() nothrow pure inout {
		return base.next;
	}

	override @property uint flags() nothrow pure const {
		return base.flags;
	}

	override const(void)[] initializer() const {
		return m_init.length ? m_init : base.initializer;
	}

	override @property size_t talign() nothrow pure const {
		return base.talign;
	}

	version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2) {
		return base.argTypes(arg1, arg2);
	}

	override @property immutable(void)* rtInfo() const {
		return base.rtInfo;
	}

	TypeInfo base; ///
	string name; ///
	void[] m_init; ///
}

class TypeInfo_Enum : TypeInfo_Typedef {

}

private size_t getArrayHash(in TypeInfo element, in void* ptr, in size_t count) @trusted nothrow {
	ubyte* p = cast(ubyte*)ptr;
	size_t hash;
	foreach (i; 0 .. element.tsize * count)
		hash = (hash << 4) + (*p) ^ 0xDEAD + i;

	return hash;
}

class TypeInfo_Array : TypeInfo {
	override string toString() const {
		return "UNK[]";
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_Array)o;
		return c && this.value == c.value;
	}

	override size_t getHash(in void* p) @trusted const {
		void[] a = *cast(void[]*)p;
		return getArrayHash(value, a.ptr, a.length);
	}

	override bool equals(in void* p1, in void* p2) const {
		void[] a1 = *cast(void[]*)p1;
		void[] a2 = *cast(void[]*)p2;
		if (a1.length != a2.length)
			return false;
		size_t sz = value.tsize;
		for (size_t i = 0; i < a1.length; i++) {
			if (!value.equals(a1.ptr + i * sz, a2.ptr + i * sz))
				return false;
		}
		return true;
	}

	override int compare(in void* p1, in void* p2) const {
		void[] a1 = *cast(void[]*)p1;
		void[] a2 = *cast(void[]*)p2;
		size_t sz = value.tsize;
		size_t len = a1.length;

		if (a2.length < len)
			len = a2.length;
		for (size_t u = 0; u < len; u++) {
			int result = value.compare(a1.ptr + u * sz, a2.ptr + u * sz);
			if (result)
				return result;
		}
		return cast(int)a1.length - cast(int)a2.length;
	}

	override @property size_t tsize() nothrow pure const {
		return (void[]).sizeof;
	}

	override const(void)[] initializer() const @trusted {
		return (cast(void*)null)[0 .. (void[]).sizeof];
	}

	override void swap(void* p1, void* p2) const {
		void[] tmp = *cast(void[]*)p1;
		*cast(void[]*)p1 = *cast(void[]*)p2;
		*cast(void[]*)p2 = tmp;
	}

	TypeInfo value; ///

	override @property inout(TypeInfo) next() nothrow pure inout {
		return value;
	}

	override @property uint flags() nothrow pure const {
		return 1;
	}

	override @property size_t talign() nothrow pure const {
		return (void[]).alignof;
	}

	version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2) {
		arg1 = typeid(size_t);
		arg2 = typeid(void*);
		return 0;
	}
}

class TypeInfo_StaticArray : TypeInfo {
	override string toString() const {
		return "UNK[UNK]";
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_StaticArray)o;
		return c && this.len == c.len && this.value == c.value;
	}

	override size_t getHash(in void* p) @trusted const {
		return getArrayHash(value, p, len);
	}

	override bool equals(in void* p1, in void* p2) const {
		size_t sz = value.tsize;

		for (size_t u = 0; u < len; u++) {
			if (!value.equals(p1 + u * sz, p2 + u * sz))
				return false;
		}
		return true;
	}

	override int compare(in void* p1, in void* p2) const {
		size_t sz = value.tsize;

		for (size_t u = 0; u < len; u++) {
			int result = value.compare(p1 + u * sz, p2 + u * sz);
			if (result)
				return result;
		}
		return 0;
	}

	override @property size_t tsize() nothrow pure const {
		return len * value.tsize;
	}

	override void swap(void* p1, void* p2) const {
		import utils : memcpy;

		void* tmp;
		size_t sz = value.tsize;
		ubyte[16] buffer;

		assert(sz < buffer.sizeof);
		tmp = buffer.ptr;

		for (size_t u = 0; u < len; u += sz) {
			size_t o = u * sz;
			memcpy(tmp, p1 + o, sz);
			memcpy(p1 + o, p2 + o, sz);
			memcpy(p2 + o, tmp, sz);
		}
	}

	override const(void)[] initializer() nothrow pure const {
		return value.initializer;
	}

	override @property inout(TypeInfo) next() nothrow pure inout {
		return value;
	}

	override @property uint flags() nothrow pure const {
		return value.flags;
	}

	override void destroy(void* p) const {
		auto sz = value.tsize;
		p += sz * len;
		foreach (i; 0 .. len) {
			p -= sz;
			value.destroy(p);
		}
	}

	override void postblit(void* p) const {
		auto sz = value.tsize;
		foreach (i; 0 .. len) {
			value.postblit(p);
			p += sz;
		}
	}

	TypeInfo value; ///
	size_t len; ///

	override @property size_t talign() nothrow pure const {
		return value.talign;
	}

	version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2) {
		arg1 = typeid(void*);
		return 0;
	}
}

class TypeInfo_Const : TypeInfo {
	override string toString() const {
		return "Const-Something"; // TODO:
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		if (typeid(this) != typeid(o))
			return false;
		return base.opEquals((cast(TypeInfo_Const)o).base);
	}

	override size_t getHash(in void* p) const {
		return base.getHash(p);
	}

	override bool equals(in void* p1, in void* p2) const {
		return base.equals(p1, p2);
	}

	override int compare(in void* p1, in void* p2) const {
		return base.compare(p1, p2);
	}

	override @property size_t tsize() nothrow pure const {
		return base.tsize;
	}

	override void swap(void* p1, void* p2) const {
		return base.swap(p1, p2);
	}

	override @property inout(TypeInfo) next() nothrow pure inout {
		return base.next;
	}

	override @property uint flags() nothrow pure const {
		return base.flags;
	}

	override const(void)[] initializer() nothrow pure const {
		return base.initializer();
	}

	override @property size_t talign() nothrow pure const {
		return base.talign;
	}

	version (X86_64) override int argTypes(out TypeInfo arg1, out TypeInfo arg2) {
		return base.argTypes(arg1, arg2);
	}

	TypeInfo base;
}

mixin(makeTypeInfo!(char, wchar, dchar, int, uint, short, ushort, byte, ubyte, long, ulong, float, double, real, void, bool)());

private string makeTypeInfo(T...)() {
	if (__ctfe) {
		string code;

		void doit(t)() {
			if (__ctfe) {
				code ~= "class TypeInfo_" ~ t.mangleof ~ " : TypeInfo {
					override string toString() const { return \"" ~ t.stringof
					~ "\"; }

					override @property size_t tsize() nothrow pure const { return " ~ t.stringof ~ ".sizeof; }
				}";
			}
		}

		foreach (t; T) {
			doit!(t)();
			//doit!(t[])();
		}
		return code;
	} else
		assert(0);
}

class TypeInfo_Ag : TypeInfo_Array {
	override bool opEquals(Object o) {
		return TypeInfo.opEquals(o);
	}

	override string toString() const {
		return "byte[]";
	}

	override size_t getHash(in void* p) @trusted const {
		return cast(size_t)p;
	}

	override bool equals(in void* p1, in void* p2) const {
		import utils : memcmp;

		byte[] s1 = *cast(byte[]*)p1;
		byte[] s2 = *cast(byte[]*)p2;

		return s1.length == s2.length && memcmp(cast(byte*)s1, cast(byte*)s2, s1.length) == 0;
	}

	override int compare(in void* p1, in void* p2) const {
		byte[] s1 = *cast(byte[]*)p1;
		byte[] s2 = *cast(byte[]*)p2;
		size_t len = s1.length;

		if (s2.length < len)
			len = s2.length;
		for (size_t u = 0; u < len; u++) {
			int result = s1[u] - s2[u];
			if (result)
				return result;
		}
		if (s1.length < s2.length)
			return -1;
		else if (s1.length > s2.length)
			return 1;
		return 0;
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(byte);
	}
}

// ubyte[]

class TypeInfo_Ah : TypeInfo_Ag {
	override string toString() const {
		return "ubyte[]";
	}

	override int compare(in void* p1, in void* p2) const {
		import utils : memcmp, strlen;

		size_t s1Len = strlen(cast(char*)p1);
		size_t s2Len = strlen(cast(char*)p2);

		if (s1Len < s2Len)
			return -1;
		else if (s1Len > s2Len)
			return 1;

		return memcmp(p1, p2, s1Len);
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(ubyte);
	}
}

// void[]

class TypeInfo_Av : TypeInfo_Ah {
	override string toString() const {
		return "void[]";
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(void);
	}
}

// bool[]

class TypeInfo_Ab : TypeInfo_Ah {
	override string toString() const {
		return "bool[]";
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(bool);
	}
}

// char[]

class TypeInfo_Aa : TypeInfo_Ah {
	override string toString() const {
		return "char[]";
	}

	override size_t getHash(in void* p) @trusted const {
		char[] s = *cast(char[]*)p;
		size_t hash = 0;

		version (all) {
			foreach (char c; s)
				hash = hash * 11 + c;
		} else {
			size_t len = s.length;
			char* str = s;

			while (1) {
				switch (len) {
				case 0:
					return hash;

				case 1:
					hash *= 9;
					hash += *cast(ubyte*)str;
					return hash;

				case 2:
					hash *= 9;
					hash += *cast(ushort*)str;
					return hash;

				case 3:
					hash *= 9;
					hash += (*cast(ushort*)str << 8) + (cast(ubyte*)str)[2];
					return hash;

				default:
					hash *= 9;
					hash += *cast(uint*)str;
					str += 4;
					len -= 4;
					break;
				}
			}
		}
		return hash;
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(char);
	}
}

// string

class TypeInfo_Aya : TypeInfo_Aa {
	override string toString() const {
		return "immutable(char)[]";
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(immutable(char));
	}
}

// const(char)[]

class TypeInfo_Axa : TypeInfo_Aa {
	override string toString() const {
		return "const(char)[]";
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(const(char));
	}
}
// long[]

class TypeInfo_Al : TypeInfo_Array {
	override bool opEquals(Object o) {
		return TypeInfo.opEquals(o);
	}

	override string toString() const {
		return "long[]";
	}

	override size_t getHash(in void* p) @trusted const {
		return cast(size_t)p;
	}

	override bool equals(in void* p1, in void* p2) const {
		import utils : memcmp;

		long[] s1 = *cast(long[]*)p1;
		long[] s2 = *cast(long[]*)p2;

		return s1.length == s2.length && memcmp(cast(void*)s1, cast(void*)s2, s1.length * long.sizeof) == 0;
	}

	override int compare(in void* p1, in void* p2) const {
		long[] s1 = *cast(long[]*)p1;
		long[] s2 = *cast(long[]*)p2;
		size_t len = s1.length;

		if (s2.length < len)
			len = s2.length;
		for (size_t u = 0; u < len; u++) {
			if (s1[u] < s2[u])
				return -1;
			else if (s1[u] > s2[u])
				return 1;
		}
		if (s1.length < s2.length)
			return -1;
		else if (s1.length > s2.length)
			return 1;
		return 0;
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(long);
	}
}

// ulong[]

class TypeInfo_Am : TypeInfo_Al {
	override string toString() const {
		return "ulong[]";
	}

	override int compare(in void* p1, in void* p2) const {
		ulong[] s1 = *cast(ulong[]*)p1;
		ulong[] s2 = *cast(ulong[]*)p2;
		size_t len = s1.length;

		if (s2.length < len)
			len = s2.length;
		for (size_t u = 0; u < len; u++) {
			if (s1[u] < s2[u])
				return -1;
			else if (s1[u] > s2[u])
				return 1;
		}
		if (s1.length < s2.length)
			return -1;
		else if (s1.length > s2.length)
			return 1;
		return 0;
	}

	override @property inout(TypeInfo) next() @nogc pure nothrow inout {
		return cast(inout)typeid(ulong);
	}
}

class TypeInfo_AC : TypeInfo {
}

class TypeInfo_Invariant : TypeInfo_Const {
	override string toString() const {
		return cast(string)("immutable(UNK)");
	}
}

class TypeInfo_Shared : TypeInfo_Const {
	override string toString() const {
		return cast(string)("shared(UNK)");
	}
}

class TypeInfo_Inout : TypeInfo_Const {
	override string toString() const {
		return cast(string)("inout(UNK)");
	}
}

/// The base class of all thrown objects.
class Throwable : Object {
	this(string msg, Throwable next = null) @safe @nogc pure nothrow {
		this.msg = msg;
		this.next = next;
	}

	this(string msg, string file, size_t line, Throwable next = null) @safe @nogc pure nothrow {
		this(msg, next);
		this.file = file;
		this.line = line;
	}

	override string toString() {
		return msg;
	}

	void toString(scope void delegate(in char[]) sink) const {
		sink(typeid(this).name);
		sink("@");
		sink(file);
		sink("(");
		sink("UNK"); //sink(sizeToTempString(line, tmpBuff, 10));
		sink(")");

		if (msg.length) {
			sink(": ");
			sink(msg);
		}
		if (info) {
			//try {
			sink("\n----------------");
			foreach (t; info) {
				sink("\n");
				sink(t);
			}
			/*}
			catch (Throwable) {
				// ignore more errors
			}*/
		}
	}

	interface TraceInfo {
		int opApply(scope int delegate(ref const(char[]))) const;
		int opApply(scope int delegate(ref size_t, ref const(char[]))) const;
		string toString() const;
	}

	string msg; /// A message describing the error.

	string file; /// The file name and line number of the D source code corresponding with where the error was thrown from.
	size_t line; /// ditto

	TraceInfo info; /// The stack trace of where the error happened.

	Throwable next; /// A reference to the next error in the list.
}

class Error : Throwable {
public:
	this(string msg, Throwable next = null) @safe @nogc pure nothrow {
		super(msg, next);
		bypassedException = null;
	}

	this(string msg, string file, size_t line, Throwable next = null) @safe @nogc pure nothrow {
		super(msg, file, line, next);
		bypassedException = null;
	}

	Throwable bypassedException;
}

extern (C) {
	void _d_unittestm(string file, uint line) {
		onAssert("_d_unittest_", file, line);
	}

	void _d_array_bounds(ModuleInfo* m, uint line) {
		_d_arraybounds(m.name, line);
	}

	void _d_arraybounds(string m, uint line) {
		onAssert("Range error", m, line);
	}

	void _d_unittest() {
	}

	void _d_assertm(ModuleInfo* m, uint line) {
		onAssert("Assertion failure", m.name, line);
	}

	void _d_assert(string file, uint line) {
		onAssert("Assertion failure", file, line);
	}

	void _d_assert_msg(string msg, string file, uint line) {
		onAssert(msg, file, line);
	}

	private void onAssert(string msg, string file, uint line) {
		asm pure nothrow {
		forever:
			hlt;
			jmp forever;
		}
	}

	deprecated Object _d_newclass(const ClassInfo ci) {
		assert(0);
	}

	void _d_throwdwarf(Throwable o) {
		assert(0, o.msg);
	}

	int _adEq2(byte[] a1, byte[] a2, TypeInfo ti) {
		if (a1.length != a2.length)
			return 0;
		for (int a = 0; a < a1.length; a++)
			if (a1[a] != a2[a])
				return 0;
		return 1;
	}

	__gshared void* _minfo_beg;
	__gshared void* _minfo_end;
	__gshared immutable(void)* _deh_beg;
	__gshared immutable(void)* _deh_end;
	struct CompilerDSOData {
		size_t _version;
		void** _slot; // can be used to store runtime data
		object.ModuleInfo** _minfo_beg, _minfo_end;
		immutable(void)* _deh_beg, _deh_end;
	}

	void _d_dso_registry(CompilerDSOData* data) {
		_minfo_beg = data._minfo_beg;
		_minfo_end = data._minfo_end;
		_deh_beg = data._deh_beg;
		_deh_end = data._deh_end;
	}

	Object _d_interface_cast(void* p, ClassInfo c) {
		Object o;

		if (p) {
			Interface* pi = **cast(Interface***)p;

			o = cast(Object)(p - pi.offset);
			return _d_dynamic_cast(o, c);
		}
		return o;
	}

	Object _d_dynamic_cast(Object o, ClassInfo c) {
		ClassInfo oc;
		size_t offset = 0;

		if (o) {
			oc = o.classinfo;
			if (_d_isbaseof2(oc, c, offset)) {
				o = cast(Object)(cast(void*)o + offset);
			} else
				o = null;
		}
		return o;
	}

	int _d_isbaseof2(ClassInfo oc, ClassInfo c, ref size_t offset) {
		if (oc is c)
			return 1;
		do {
			if (oc.base is c)
				return 1;
			foreach (i; 0 .. oc.interfaces.length) {
				auto ic = oc.interfaces[i].classinfo;
				if (ic is c) {
					offset = oc.interfaces[i].offset;
					return 1;
				}
			}
			foreach (i; 0 .. oc.interfaces.length) {
				auto ic = oc.interfaces[i].classinfo;
				if (_d_isbaseof2(ic, c, offset)) {
					offset = oc.interfaces[i].offset;
					return 1;
				}
			}
			oc = oc.base;
		}
		while (oc);
		return 0;
	}

	int _d_isbaseof(ClassInfo oc, ClassInfo c) {
		if (oc is c)
			return 1;
		do {
			if (oc.base is c)
				return 1;
			foreach (i; 0 .. oc.interfaces.length) {
				auto ic = oc.interfaces[i].classinfo;
				if (ic is c || _d_isbaseof(ic, c))
					return 1;
			}
			oc = oc.base;
		}
		while (oc);
		return 0;
	}

	/*********************************
 * Find the vtbl[] associated with Interface ic.
 */

	void* _d_interface_vtbl(ClassInfo ic, Object o) {
		assert(o);

		auto oc = o.classinfo;
		foreach (i; 0 .. oc.interfaces.length) {
			auto oic = oc.interfaces[i].classinfo;
			if (oic is ic) {
				return cast(void*)oc.interfaces[i].vtbl;
			}
		}
		assert(0);
	}
}
