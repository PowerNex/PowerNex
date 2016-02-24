module object;

import IO.Log;

// over 3/4 of this file was copy/pasted from the real druntime with little to no modification

/*
with an empty main:
	$ make
	$ strip minimal; ls -lh minimal
	-rwxr-xr-x 1 me users 32K 2013-06-01 10:22 minimal
	$ file minimal
	minimal: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, stripped

	not bad.
*/

/**
	What doesn't work:
		1) array concats. use the module memory.d instead (link failure)
		2) module constructors and destructors (silent failure)
		3) looping ModuleInfo without libc or bare metal (silent failure)
		4) TLS variables. always use __gshared (runtime crash)
		5) threads.
		6) unittests (silent failure)


	Warnings:
		1) don't store slices or built in arrays. if you need to store an array, see the module memory.d and try HeapArray
		2) don't store delegates. Indeed, don't use delegates unless they are marked scope.

		Instead use HeapArray and HeapClosure, which are refcounted.

		It is ok to pass slices or scope delegates, just don't store them because they might be freed unexpectedly.

		Maybe we shouldn't free immutable stuff, so they can be safe to store, idk.

		3) if you catch an exception, you should call manual_free() on the throwable object at the end of the catch scope (unless you intend to rethrow it, of course)
*/

/**
	versions:
		bare_metal: brings its own code instead of using Linux (use Makefile.bare)
		without_exceptions: no exception support, throw will be a linker error. note the compiler still generates the handler info tables anyway...
		without_moduleinfo: some assert and range errors won't show names, less reflection options. not sure if this actually matters tbh, i think the compiler outputs the data anyway

		with_libc: uses the system C library (default is totally standalone. use "make LIBC=yes")

		without_custom_runtime_reflection: runtime reflection will be bare minimum, don't use typeinfo except as like an opaque pointer. You also won't need the special linker script if you go without libc with this option.
*/

nothrow pure size_t strlen(const(char)* c) {
	if (c is null)
		return 0;

	size_t l = 0;
	while (*c) {
		c++;
		l++;
	}
	return l;
}

void main() {
}

extern (C) int kmain(uint magic, ulong info);
int callKmain(uint magic, ulong info) {
	try {
		return kmain(magic, info);
	}
	catch (Throwable t) {
		log.Info("\n**UNCAUGHT EXCEPTION**\n");
		t.print();
		t.destroy;
		return (1);
	}
}

__gshared string[] environment;

extern (C) void _Dkmain_entry(uint magic, ulong info) {
	exit(callKmain(magic, info));
}

void exit(ssize_t code = 0) {
	asm {
		cli;
	stay_dead:
		hlt;
		jmp stay_dead;
	}
}

__gshared multiboot_info* bootInfo;

struct multiboot_info {
	uint flags;
	uint mem_lower;
	uint mem_upper;
	uint boot_devide;
	uint cmdline;
	uint mods_addr;
	uint somethingInAInion;

	uint memoryMapBytes;
	uint memoryMapAddress;
}

struct multiboot_memory_map {
	uint size;
	uint base_addr_low, base_addr_hight;
	uint length_low, length_high;
	uint type;
}

extern (C) {
	// the compiler spits this out all the time
	Object _d_newclass(const ClassInfo ci) {
		log.Debug("Creating a new class of type: ", ci.name);
		void* memory = GetKernelHeap.Alloc(ci.init.length);
		if (memory is null) {
			log.Info("\n\n_d_newclass malloc failure\n\n");
			exit();
		}

		(cast(ubyte*)memory)[0 .. ci.init.length] = cast(ubyte[])ci.init[];
		return cast(Object)memory;
	}

	void[] _d_newarrayT(TypeInfo ti, size_t length) {
		auto size = ti.next.tsize();

		if (!length || !size)
			return null;
		else
			return GetKernelHeap.Alloc(length * size)[0 .. length];
	}

	void* _d_arrayliteralTX(TypeInfo ti, size_t length) {
		auto size = ti.next.tsize();

		if (!length || !size)
			return null;
		else
			return GetKernelHeap.Alloc(length * size);
	}

	void[] _d_arraycatT(TypeInfo ti, void[] x, void[] y) {
		log.Fatal(ti.toString);
		auto size = ti.next.tsize();

		if (!(x.length + y.length) || !size)
			return null;

		ubyte* data = cast(ubyte*)GetKernelHeap.Alloc((x.length + y.length) * size);
		memcpy(data, x.ptr, x.length * size);
		memcpy(data + (x.length * size), y.ptr, y.length * size);
		return (cast(void*)data)[0 .. x.length + y.length];
	}

	void[] _d_arraysetlengthT(const TypeInfo ti, size_t newlength, void[]* p) {
		auto size = ti.next.tsize();
		log.Info("ti: ", ti.toString, "(", ti.next.toString, " = ", size, ") newlength: ", newlength, " p: ", p);
		*p = GetKernelHeap.Realloc(p.ptr, newlength * size)[0 .. newlength];
		return *p;
	}

	byte[] _d_arrayappendcTX(const TypeInfo ti, ref byte[] px, size_t n) {
		auto size = ti.next.tsize();
		auto newlength = px.length + n;
		void* newPtr = GetKernelHeap.Realloc(px.ptr, newlength * size);
		*cast(size_t*)&px = newlength;
		(cast(void**)(&px))[1] = newPtr;
		return px;
	}

	// and these came when I started using foreach
	void _d_unittestm(string file, uint line) {
		log.Info("_d_unittest_");
		exit(1);
	}

	void _d_array_bounds(ModuleInfo* m, uint line) {
		_d_arraybounds(m.name, line);
	}

	void _d_arraybounds(string m, uint line) {
		throw new Error("Range error", m, line);
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
		throw new AssertError(msg, file, line);
	}
}

char[] intToString(ssize_t i, char[] buffer) {
	ssize_t pos = buffer.length - 1;

	if (i == 0) {
		buffer[pos] = '0';
		pos--;
	}

	while (pos > 0 && i) {
		buffer[pos] = (i % 10) + '0';
		pos--;
		i /= 10;
	}

	return buffer[pos + 1 .. $];
}

// extern(C) void printf(const char*, ...);

alias immutable(char)[] string;
// the next few are really only there for phobos... they don't actually work right
alias immutable(wchar)[] wstring;
alias immutable(dchar)[] dstring;

alias ulong size_t;
alias ulong sizediff_t;
alias long ptrdiff_t;
alias long ssize_t;

/* ******************************** */
/*          Basic D classes         */
/* ******************************** */

bool opEquals(const Object lhs, const Object rhs) {
	// A hack for the moment.
	return lhs is rhs;
}

class Object {
	string toString() const {
		return "";
	} // for D
	bool opEquals(Object rhs) {
		return rhs is this;
	}

	bool opEquals(Object lhs, Object rhs) {
		if (lhs is rhs)
			return true;
		if (lhs is null || rhs is null)
			return false;
		if (typeid(lhs) == typeid(rhs))
			return lhs.opEquals(rhs);
		return lhs.opEquals(rhs) && rhs.opEquals(lhs);
	}

	int opCmp(Object o) {
		return 0;
	}

	size_t toHash() nothrow @trusted const {
		return cast(size_t)cast(void*)this;
	}
}

class Throwable : Object { // required by the D compiler

	interface TraceInfo {
		int opApply(scope int delegate(ref const(char[]))) const;
		int opApply(scope int delegate(ref size_t, ref const(char[]))) const;
		string toString() const;
	}

	Throwable next;

	~this() {
		if (next !is null)
			next.destroy;
	}

	string message;
	alias message msg;
	string file;
	size_t line;
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		this.message = msg;
		this.file = file;
		this.line = line;
	}

	override string toString() const {
		return message;
	}

	void print() {
		log.Fatal(this.classinfo.name, "@", file, "(", line, "): ", message, "\n");
	}
}

class Error : Throwable { // required by the D compiler
	Throwable bypassedException;
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}

	~this() {
		if (bypassedException !is null)
			bypassedException.destroy;
	}
}

class Exception : Throwable { // required by the D compiler
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

/// thrown by our assert function
class AssertError : Error {
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}
}

struct AssociativeArray(K, V) {
	typeof(this) dup() {
		return this;
	} // FIXME
}

class TypeInfo {
	override string toString() const pure @safe nothrow {
		return typeid(this).name;
	}

	@property immutable(MoreTypeInfo*) rtInfo() nothrow pure const @safe {
		return null;
	}
	/// Returns a hash of the instance of a type.
	size_t getHash(in void* p) @trusted nothrow const {
		return cast(size_t)p;
	}

	/// Compares two instances for equality.
	bool equals(in void* p1, in void* p2) const {
		return p1 == p2;
	}

	/// Compares two instances for &lt;, ==, or &gt;.
	int compare(in void* p1, in void* p2) const {
		return 0;
	}

	/// Returns size of the type.
	@property size_t tsize() nothrow pure const @safe {
		return 0;
	}

	/// Swaps two instances of the type.
	void swap(void* p1, void* p2) const {
		size_t n = tsize;
		for (size_t i = 0; i < n; i++) {
			byte t = (cast(byte*)p1)[i];
			(cast(byte*)p1)[i] = (cast(byte*)p2)[i];
			(cast(byte*)p2)[i] = t;
		}
	}

	/// Get TypeInfo for 'next' type, as defined by what kind of type this is,
	/// null if none.
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

	//byte[] init() { return  null;}

	override size_t toHash() @trusted const {
		try {
			//import rt.util.hash;
			auto data = this.toString();
			//return hashOf(data.ptr, data.length);
			return 0;
		}
		catch (Throwable) {
			// This should never happen; remove when toString() is made nothrow

			// BUG: this prevents a compacting GC from working, needs to be fixed
			return cast(size_t)cast(void*)this;
		}
	}

	override int opCmp(Object o) {
		if (this is o)
			return 0;
		return 1;
		//TypeInfo ti = cast(TypeInfo)o;
		//if (ti is null)
		return 1;
		//return dstrcmp(this.toString(), ti.toString());
		return 1;
	}

	/// Return alignment of type
	@property size_t talign() nothrow pure const @safe {
		return tsize;
	}

	@property const(TypeInfo) next() nothrow pure const {
		return null;
	}

	const(void)[] init() nothrow pure const @safe {
		return null;
	}

	/// Get flags for type: 1 means GC should scan for pointers
	@property uint flags() nothrow pure const @safe {
		return 0;
	}

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

	override @property const(TypeInfo) next() nothrow pure const {
		return cast(inout)typeid(byte);
	}
}

// ubyte[]

class TypeInfo_Ah : TypeInfo_Ag {
	override string toString() const {
		return "ubyte[]";
	}

	override int compare(in void* p1, in void* p2) const {
		char[] s1 = *cast(char[]*)p1;
		char[] s2 = *cast(char[]*)p2;

		return dstrcmp(s1, s2);
	}

	override @property const(TypeInfo) next() nothrow pure const {
		return cast(inout)typeid(ubyte);
	}
}

// void[]

class TypeInfo_Av : TypeInfo_Ah {
	override string toString() const {
		return "void[]";
	}

	override @property const(TypeInfo) next() nothrow pure const {
		return cast(inout)typeid(void);
	}
}

// bool[]

class TypeInfo_Ab : TypeInfo_Ah {
	override string toString() const {
		return "bool[]";
	}

	override @property const(TypeInfo) next() nothrow pure const {
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

	override @property const(TypeInfo) next() nothrow pure const {
		return cast(inout)typeid(char);
	}
}

// string

class TypeInfo_Aya : TypeInfo_Aa {
	override string toString() const {
		return "immutable(char)[]";
	}

	override @property const(TypeInfo) next() nothrow pure const {
		return cast(inout)typeid(immutable(char));
	}
}

// const(char)[]

class TypeInfo_Axa : TypeInfo_Aa {
	override string toString() const {
		return "const(char)[]";
	}

	override @property const(TypeInfo) next() nothrow pure const {
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

	override @property const(TypeInfo) next() nothrow pure const {
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

	override @property const(TypeInfo) next() nothrow pure const {
		return cast(inout)typeid(ulong);
	}
}

class TypeInfo_StaticArray : TypeInfo {
	override string toString() const {
		return value.toString() ~ "[TODO]";
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

	override const(void)[] init() nothrow pure const {
		return value.init();
	}

	override @property const(TypeInfo) next() nothrow pure const {
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

	TypeInfo value;
	size_t len;

	override @property size_t talign() nothrow pure const {
		return value.talign;
	}
}

class TypeInfo_Function : TypeInfo {
	TypeInfo next;
	string deco;
}

class TypeInfo_Interface : TypeInfo {
	override string toString() const {
		return info.name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto c = cast(const TypeInfo_Interface)o;
		return c && this.info.name == c.classinfo.name;
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

		// Regard null references as always being "less than"
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

	override @property uint flags() nothrow pure const {
		return 1;
	}

	TypeInfo_Class info;
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

	override const(void)[] init() nothrow pure const @safe {
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

	immutable(MoreTypeInfo)* m_RTInfo; // data for precise GC
	override @property immutable(MoreTypeInfo*) rtInfo() nothrow pure const @safe {
		return m_RTInfo;
	}

	/**
     * Search all modules for TypeInfo_Class corresponding to classname.
     * Returns: null if not found
     */
	static const(TypeInfo_Class) find(in char[] classname) {
		foreach (m; ModuleInfo) {
			if (m) //writefln("module %s, %d", m.name, m.localClasses.length);
				foreach (c; m.localClasses) {
					if (c is null)
						continue;
					//writefln("\tclass %s", c.name);
					if (c.name == classname)
						return c;
				}
		}
		return null;
	}

	/**
     * Create instance of Object represented by 'this'.
     */
	Object create() const {
		if (m_flags & 8 && !defaultConstructor)
			return null;
		if (m_flags & 64) // abstract
			return null;
		Object o = _d_newclass(this);
		if (m_flags & 8 && defaultConstructor) {
			defaultConstructor(o);
		}
		return o;
	}
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

	override @property const(TypeInfo) next() nothrow pure const {
		return base.next;
	}

	override @property uint flags() nothrow pure const {
		return base.flags;
	}

	override const(void)[] init() const {
		return m_init.length ? m_init : base.init();
	}

	override @property size_t talign() nothrow pure const {
		return base.talign;
	}

	override @property immutable(MoreTypeInfo*) rtInfo() nothrow pure const @safe {
		return base.rtInfo;
	}

	TypeInfo base;
	string name;
	void[] m_init;
}

class TypeInfo_Enum : TypeInfo_Typedef {

}

mixin(makeTypeInfo!(char, wchar, dchar, int, uint, short, ushort, byte, ubyte, long, ulong, float, double, real, void, bool)());

private string makeTypeInfo(T...)() {
	if (__ctfe) {
		string code;

		void doit(t)() {
			if (__ctfe) {
				code ~= "class TypeInfo_" ~ t.mangleof ~ " : TypeInfo {
					override string toString() const { return \"" ~ t.stringof ~ "\"; }

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

class TypeInfo_AC : TypeInfo {
}

class TypeInfo_Pointer : TypeInfo {
	void* stuff;
}

private size_t getArrayHash(in TypeInfo element, in void* ptr, in size_t count) @trusted nothrow {
	if (!count)
		return 0;

	const size_t elementSize = element.tsize;
	if (!elementSize)
		return 0;

	return cast(size_t)ptr;
}

class TypeInfo_Array : TypeInfo {
	override string toString() const {
		return value.toString(); // ~ "[]";
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

	override const(void)[] init() const @trusted {
		return (cast(void*)null)[0 .. (void[]).sizeof];
	}

	override void swap(void* p1, void* p2) const {
		void[] tmp = *cast(void[]*)p1;
		*cast(void[]*)p1 = *cast(void[]*)p2;
		*cast(void[]*)p2 = tmp;
	}

	TypeInfo value;

	override @property const(TypeInfo) next() nothrow pure const {
		return value;
	}

	override @property uint flags() nothrow pure const {
		return 1;
	}

	override @property size_t talign() nothrow pure const {
		return (void[]).alignof;
	}
}

class TypeInfo_Const : TypeInfo {
	void* whatever;
}

class TypeInfo_Invariant : TypeInfo_Const {
}

class TypeInfo_Shared : TypeInfo_Const {
}

class TypeInfo_Inout : TypeInfo_Const {
}

class TypeInfo_Struct : TypeInfo {
	override string toString() const {
		return name;
	}

	override bool opEquals(Object o) {
		if (this is o)
			return true;
		auto s = cast(const TypeInfo_Struct)o;
		return s && this.name == s.name && this.init().length == s.init().length;
	}

	override size_t getHash(in void* p) @safe pure nothrow const {
		return cast(size_t)p;
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
			return memcmp(p1, p2, init().length) == 0;
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
					return memcmp(p1, p2, init().length);
			} else
				return -1;
		}
		return 0;
	}

	override @property size_t tsize() nothrow pure const {
		return init().length;
	}

	override const(void)[] init() nothrow pure const @safe {
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
		uint function(in void*) xtoHash;
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

	TypeInfo m_arg1;
	TypeInfo m_arg2;

	override @property immutable(MoreTypeInfo*) rtInfo() nothrow pure const @safe {
		return null;
	}

	immutable(void*) m_RTInfo; // data for precise GC
}

alias TypeInfo_Class ClassInfo;

struct Interface {
	TypeInfo_Class classinfo; /// .classinfo for this interface (not for containing class)
	void*[] vtbl;
	ptrdiff_t offset; /// offset to Interface 'this' from Object 'this'
}

/**
 * Array of pairs giving the offset and type information for each
 * member in an aggregate.
 */
struct OffsetTypeInfo {
	size_t offset; /// Offset of member from start of object
	TypeInfo ti; /// TypeInfo for this member
}

struct MoreTypeInfo {
	hash_t hash;
	string stringOf;

	immutable(void)* userRtInfo;
	immutable(CustomTypeInfoExtension)[] customInfo;

	immutable(T)* getCustomInfo(T)() immutable {
		auto hash = typeid(T); // typehash!T;
		foreach (ci; customInfo) {
			if (ci.typeOfData == hash)
				return cast(immutable(T)*)ci.data();
		}
		return null;
	}
}

struct CustomTypeInfoExtension {
	TypeInfo typeOfData;
	void* function() data;
}

immutable(CustomTypeInfoExtension)[] getCustomInfoInternal(T)() {
	if (__ctfe) {
		//bool[hash_t] seen;
		immutable(CustomTypeInfoExtension)[] ext;
		foreach (attr; __traits(getAttributes, T))
			static if (is(typeof(attr) == CustomTypeInfoExtension)) {
				//auto hash = attr.typeOfData.rtInfo.hash;
				//if(hash in seen)
				//assert(0, "repeated data");
				//seen[hash] = true;
				ext ~= cast(immutable)attr;
			}
		return ext;
	} else
		return null;
}

template CustomInfo(alias T) {
	__gshared static data = T;
	void* getRaw() {
		return cast(void*)&data;
	}

	enum CustomInfo = CustomTypeInfoExtension(typeid(typeof(data)) /*typehash!(typeof(data))*/ , &getRaw);
}

template urtInfo(T) {
	static if (__traits(compiles, { auto a = cast(immutable(void)*)T.userRtInfo!T; }))
		enum urtInfo = cast(immutable(void)*)T.userRtInfo!T;
	else
		enum urtInfo = null;
}

enum CustomCtCheckResult {
	fail,
	pass
}

template CustomCheck(alias C) {
	template CustomCheck(T) {
		static if (__traits(compiles, C!T))
			enum CustomCheck = CustomCtCheckResult.pass;
		else
			enum CustomCheck = CustomCtCheckResult.fail;
	}
}

bool doCustomChecks(T)() {
	if (__ctfe) {
		foreach (attr; __traits(getAttributes, T)) {
			static if (is(typeof(attr!T) == CustomCtCheckResult)) {
				static assert(attr!T == CustomCtCheckResult.pass);
				/*
					static if(attr!T == CustomCtCheckResult.fail) {

					}
					pragma(msg, attr.stringof);
					*/
			}
		}
		return true;
	}
	assert(0);
}

enum Test;

template RTInfo(T) {
	//	pragma(msg, T.stringof);
	__gshared static immutable minfo = MoreTypeInfo(typehash!T, T.stringof, urtInfo!T, getCustomInfoInternal!T);

	enum customChecksPassed = doCustomChecks!T;

	enum RTInfo = &minfo;
}

extern (C) __gshared void* _Dmodule_ref;

extern (C) byte[] _d_arraycopy(size_t size, byte[] from, byte[] to) {
	if (to.length != from.length) {
		throw new Exception("lengths don't match for array copy");
	} else if (to.ptr + to.length * size <= from.ptr || from.ptr + from.length * size <= to.ptr) {
		size_t s = to.length * size;
		byte* b1 = from.ptr;
		byte* b2 = to.ptr;
		while (s) {
			*b2 = *b1;
			++b2;
			++b1;
			--s;
		}
	} else {
		throw new Exception("overlapping array copy");
	}
	return to;
}

extern (C) ssize_t _d_switch_string(char[][] table, char[] it) {
	foreach (i, item; table)
		if (item == it)
			return i;
	return -1;
}

// these byte[] are supposed to be void[]
extern (C) int _adEq2(byte[] a1, byte[] a2, TypeInfo ti) {
	if (a1.length != a2.length)
		return 0;
	for (int a = 0; a < a1.length; a++)
		if (a1[a] != a2[a])
			return 0;
	return 1;
}

// immutable allocs are on a special heap that are never freed
// so you should use sparingly
immutable(T)[] immutable_alloc(T)(T[] dataToCopy) {
	return null;
}

immutable(T)[] immutable_alloc(T)(scope void delegate(T[]) initalizer) {
	return null;
}

import Memory.Heap;

void destroy(void* memory) {
	GetKernelHeap.Free(memory);
}

void destroy(Object object) {
	auto dtor = cast(void function(Object o))object.classinfo.destructor;
	if (dtor)
		dtor(object);
	GetKernelHeap.Free(cast(void*)object);
}

void destroy(T)(T[] array) {
	static if (is(typeof(T) == Object)) {
		foreach (ref el; array) {
			auto dtor = cast(void function(Object o))T.classinfo.destructor;
			if (dtor)
				dtor(el);
		}
	}
	GetKernelHeap.Free(cast(void*)array.ptr);
}

// this would be used for automatic heap closures, but there's no way to free it...
///*
extern (C) void* _d_allocmemory(size_t bytes) {
	return GetKernelHeap.Alloc(bytes);
}
//*/

extern (C):

/******************************************
 * Given a pointer:
 *      If it is an Object, return that Object.
 *      If it is an interface, return the Object implementing the interface.
 *      If it is null, return null.
 *      Else, undefined crash
 */

Object _d_toObject(void* p) {
	Object o;

	if (p) {
		o = cast(Object)p;
		ClassInfo oc = o.classinfo;
		Interface* pi = **cast(Interface***)p;

		/* Interface.offset lines up with ClassInfo.name.ptr,
         * so we rely on pointers never being less than 64K,
         * and Objects never being greater.
         */
		if (pi.offset < 0x10000) {
			o = cast(Object)(p - pi.offset);
		}
	}
	return o;
}

/*************************************
 * Attempts to cast Object o to class c.
 * Returns o if successful, null if not.
 */

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

// copy/pasted from deh2.d in druntimes source
// exception handling

/**
 * Written in the D programming language.
 * Implementation of exception handling support routines for Posix and Win64.
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_deh2.d)
 */

//debug=1;
//debug import core.stdc.stdio : printf;

extern (C) {
	Throwable.TraceInfo _d_traceContext(void* ptr = null);

	int _d_isbaseof(ClassInfo oc, ClassInfo c);

	void _d_createTrace(Object*) {
	}
}

alias int function() fp_t; // function pointer in ambient memory model

// DHandlerInfo table is generated by except_gentables() in eh.c

struct DHandlerInfo {
	uint offset; // offset from function address to start of guarded section
	uint endoffset; // offset of end of guarded section
	int prev_index; // previous table index
	uint cioffset; // offset to DCatchInfo data from start of table (!=0 if try-catch)
	size_t finally_offset; // offset to finally code to execute
	// (!=0 if try-finally)
}

// Address of DHandlerTable, searched for by eh_finddata()

struct DHandlerTable {
	uint espoffset; // offset of ESP from EBP
	uint retoffset; // offset from start of function to return code
	size_t nhandlers; // dimension of handler_info[] (use size_t to set alignment of handler_info[])
	DHandlerInfo handler_info[1];
}

struct DCatchBlock {
	ClassInfo type; // catch type
	size_t bpoffset; // EBP offset of catch var
	size_t codeoffset; // catch handler offset
}

// Create one of these for each try-catch
struct DCatchInfo {
	size_t ncatches; // number of catch blocks
	DCatchBlock catch_block[1]; // data for each catch block
}

// One of these is generated for each function with try-catch or try-finally

struct FuncTable {
	void* fptr; // pointer to start of function
	DHandlerTable* handlertable; // eh data for this function
	uint fsize; // size of function in bytes
}

private {
	struct InFlight {
		InFlight* next;
		void* addr;
		Throwable t;
	}

	__gshared InFlight* __inflight = null;
}

void terminate() {
	log.Info("Uncaught exception or busted up stack\n");
	exit();
}

FuncTable* __eh_finddata(void* address) {
	auto pstart = cast(FuncTable*)&_deh_beg;
	auto pend = cast(FuncTable*)&_deh_end;

	for (auto ft = pstart; 1; ft++) {
	Lagain:
		if (ft >= pend)
			break;

		void* fptr = ft.fptr;
		if (fptr <= address && address < cast(void*)(cast(char*)fptr + ft.fsize)) {
			return ft;
		}
	}
	return null;
}

/******************************
 * Given EBP, find return address to caller, and caller's EBP.
 * Input:
 *   regbp       Value of EBP for current function
 *   *pretaddr   Return address
 * Output:
 *   *pretaddr   return address to caller
 * Returns:
 *   caller's EBP
 */

size_t __eh_find_caller(size_t regbp, size_t* pretaddr) {
	size_t bp = *cast(size_t*)regbp;

	if (bp) // if not end of call chain
	{
		// Perform sanity checks on new EBP.
		// If it is screwed up, terminate() hopefully before we do more damage.
		if (bp <= regbp) // stack should grow to smaller values
			terminate();

		*pretaddr = *cast(size_t*)(regbp + size_t.sizeof);
	}
	return bp;
}

/***********************************
 * Throw a D object.
 */

extern (C) void _d_throwc(Object* h) {
	size_t regebp;

	asm {
		mov regebp, RBP;
	}

	_d_createTrace(h);

	//static uint abc;
	//if (++abc == 2) *(char *)0=0;

	//int count = 0;
	while (1) // for each function on the stack
	{
		size_t retaddr;

		regebp = __eh_find_caller(regebp, &retaddr);
		if (!regebp) { // if end of call chain
			break;
		}

		//if (++count == 12) *(char*)0=0;
		auto func_table = __eh_finddata(cast(void*)retaddr); // find static data associated with function
		auto handler_table = func_table ? func_table.handlertable : null;
		if (!handler_table) // if no static data
		{
			continue;
		}
		auto funcoffset = cast(size_t)func_table.fptr;
		auto spoff = handler_table.espoffset;
		auto retoffset = handler_table.retoffset;

		// Find start index for retaddr in static data
		auto dim = handler_table.nhandlers;

		auto index = -1;
		for (int i = 0; i < dim; i++) {
			auto phi = &handler_table.handler_info.ptr[i];

			if (retaddr > funcoffset + phi.offset && retaddr <= funcoffset + phi.endoffset)
				index = i;
		}

		if (dim) {
			auto phi = &handler_table.handler_info.ptr[index + 1];
			auto prev = cast(InFlight*)&__inflight;
			auto curr = prev.next;

			if (curr !is null && curr.addr == cast(void*)(funcoffset + phi.finally_offset)) {
				auto e = cast(Error)(cast(Throwable)h);
				if (e !is null && (cast(Error)curr.t) is null) {

					e.bypassedException = curr.t;
					prev.next = curr.next;
					//h = cast(Object*) t;
				} else {

					auto t = curr.t;
					auto n = curr.t;

					while (n.next)
						n = n.next;
					n.next = cast(Throwable)h;
					prev.next = curr.next;
					h = cast(Object*)t;
				}
			}
		}

		// walk through handler table, checking each handler
		// with an index smaller than the current table_index
		int prev_ndx;
		for (auto ndx = index; ndx != -1; ndx = prev_ndx) {
			auto phi = &handler_table.handler_info.ptr[ndx];
			prev_ndx = phi.prev_index;
			if (phi.cioffset) {
				// this is a catch handler (no finally)

				auto pci = cast(DCatchInfo*)(cast(char*)handler_table + phi.cioffset);
				auto ncatches = pci.ncatches;
				for (int i = 0; i < ncatches; i++) {
					auto ci = **cast(ClassInfo**)h;

					auto pcb = &pci.catch_block.ptr[i];

					if (_d_isbaseof(ci, pcb.type)) {
						// Matched the catch type, so we've found the handler.

						// Initialize catch variable
						*cast(void**)(regebp + (pcb.bpoffset)) = h;

						// Jump to catch block. Does not return.
						{
							size_t catch_esp;
							fp_t catch_addr;

							catch_addr = cast(fp_t)(funcoffset + pcb.codeoffset);
							catch_esp = regebp - handler_table.espoffset - fp_t.sizeof;
							asm {
								mov RAX, catch_esp;
								mov RCX, catch_esp;
								mov RCX, catch_addr;
								mov [RAX], RCX;
								mov RBP, regebp;
								mov RSP, RAX; // reset stack
								ret; // jump to catch block
							}
						}
					}
				}
			} else if (phi.finally_offset) {
				// Call finally block
				// Note that it is unnecessary to adjust the ESP, as the finally block
				// accesses all items on the stack as relative to EBP.

				auto blockaddr = cast(void*)(funcoffset + phi.finally_offset);
				InFlight inflight;

				inflight.addr = blockaddr;
				inflight.next = __inflight;
				inflight.t = cast(Throwable)h;
				__inflight = &inflight;

				asm {
					sub RSP, 8;
					push RBX;
					mov RBX, blockaddr;
					push RBP;
					mov RBP, regebp;
					call RBX;
					pop RBP;
					pop RBX;
					add RSP, 8;
				}

				if (__inflight is &inflight)
					__inflight = __inflight.next;
			}
		}
	}
	terminate();
}

///////////////////////////////////////////////////////////////////////////////
// ModuleInfo
///////////////////////////////////////////////////////////////////////////////

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

struct ModuleInfo {
	uint _flags;
	uint _index; // index into _moduleinfo_array[]

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

/* moved from version(compiler_dso) below */
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

extern (C) void _d_dso_registry(CompilerDSOData* data) {
	_minfo_beg = data._minfo_beg;
	_minfo_end = data._minfo_end;
	_deh_beg = data._deh_beg;
	_deh_end = data._deh_end;
}

/* **** */
// hash function

// the following is copy/pasted from druntime src/rt/util/hash.d
// is that available as an import somewhere in the stdlib?

template typehash(T) {
	enum typehash = hashOf(T.mangleof.ptr, T.mangleof.length);
}

alias size_t hash_t;

@trusted pure nothrow hash_t hashOf(const(void)* buf, size_t len, hash_t seed = 0) {
	/*
     * This is Paul Hsieh's SuperFastHash algorithm, described here:
     *   http://www.azillionmonkeys.com/qed/hash.html
     * It is protected by the following open source license:
     *   http://www.azillionmonkeys.com/qed/weblicense.html
     */
	static uint get16bits(const(ubyte)* x) pure nothrow {
		// CTFE doesn't support casting ubyte* -> ushort*, so revert to
		// per-byte access when in CTFE.

		return ((cast(uint)x[1]) << 8) + (cast(uint)x[0]);
	}

	// NOTE: SuperFastHash normally starts with a zero hash value.  The seed
	//       value was incorporated to allow chaining.
	auto data = cast(const(ubyte)*)buf;
	auto hash = seed;
	int rem;

	if (len <= 0 || data is null)
		return 0;

	rem = len & 3;
	len >>= 2;

	for (; len > 0; len--) {
		hash += get16bits(data);
		auto tmp = (get16bits(data + 2) << 11) ^ hash;
		hash = (hash << 16) ^ tmp;
		data += 2 * ushort.sizeof;
		hash += hash >> 11;
	}

	switch (rem) {
	case 3:
		hash += get16bits(data);
		hash ^= hash << 16;
		hash ^= data[ushort.sizeof] << 18;
		hash += hash >> 11;
		break;
	case 2:
		hash += get16bits(data);
		hash ^= hash << 11;
		hash += hash >> 17;
		break;
	case 1:
		hash += *data;
		hash ^= hash << 10;
		hash += hash >> 1;
		break;
	default:
		break;
	}

	/* Force "avalanching" of final 127 bits */
	hash ^= hash << 3;
	hash += hash >> 5;
	hash ^= hash << 4;
	hash += hash >> 17;
	hash ^= hash << 25;
	hash += hash >> 6;

	return hash;
}

bool _xopEquals(in void*, in void*) {
	assert(0);
}

extern (C) void _d_run_main() {
}

extern (C) void* _memset64(void* p, ulong value, int count) {
	ulong* ptr = cast(ulong*)p;

	for (int i = 0; i < count; i += 8)
		*ptr = value;
	return p;
}

extern (C) void* memcpy(void* dest, const(void)* src, size_t size) {
	for (size_t i = 0; i < size; ++i)
		(cast(ubyte*)dest)[i] = (cast(const(ubyte)*)src)[i];
	return dest;
}

extern (C) int memcmp(void* src1, void* src2, size_t size) {
	ubyte* s1 = cast(ubyte*)src1;
	ubyte* s2 = cast(ubyte*)src2;
	while (size--) {
		if (s1 < s2)
			return 1;
		else if (s2 < s1)
			return -1;
	}
	return 0;
}

extern (C) int dstrcmp(char[] s1, char[] s2) {
	int ret = 0;
	auto len = s1.length;
	if (s2.length < len)
		len = s2.length;
	if (0 != (ret = memcmp(s1.ptr, s2.ptr, len)))
		return ret;
	return s1.length > s2.length ? 1 : s1.length == s2.length ? 0 : -1;
}

extern (C) Throwable __dmd_begin_catch(_Unwind_Exception* exceptionObject) {
	log.Error("STUB");
	return null;
}

extern (C) void _d_throwdwarf(Throwable o) {
	o.print();
}

alias int _Unwind_Reason_Code;
alias int _Unwind_Action;
struct _Unwind_Exception {
}

struct _Unwind_Context {
}

alias ulong _Unwind_Exception_Class;
extern (C) _Unwind_Reason_Code __dmd_personality_v0(int ver, _Unwind_Action actions,
		_Unwind_Exception_Class exceptionClass, _Unwind_Exception* exceptionObject, _Unwind_Context* context) {
	log.Error("STUB");
	return 0;
}
