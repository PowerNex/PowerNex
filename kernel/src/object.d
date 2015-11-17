module object;
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

// FIXME it would be great if this actually worked on windows too
version(Windows)
	version=with_libc; // no reason not to, Windows will always have it anyway

version(with_libc) {
	extern(C) {
		private {
			// you should import core.stdc from real druntime or something instead
			void* malloc(size_t);
			void free(void*);
			void* realloc(void*, size_t);
			void *memcpy(void *dest, const void *src, size_t n);

			struct FILE;
			extern __gshared FILE* stdout;
			size_t fwrite(in void*, size_t, size_t, FILE*);
		}
	}
	version=use_malloc;
	version=compiler_dso;
}

version(linux) {
	// first we want to be able to write some stuff to see progress

	version(bare_metal) {
		import io.textmode;
	} else {
		version=compiler_dso; // FIXME: it doesn't actually work without libc!
	}

	void write_raw(ssize_t i, ssize_t fd = 1) {
		char[16] buffer;
		write_raw(intToString(i, buffer), fd);
	}

	void write_raw(in void[] a, ssize_t fd = 1) {
		version(with_libc) {
			fwrite(a.ptr, 1, a.length, stdout);
		} else version(bare_metal) {
			GetScreen.Write(cast(char[])a);
		} else {
			auto sptr = a.ptr;
			auto slen = a.length;
			version(D_InlineAsm_X86)
			asm {
				mov ECX, sptr;
				mov EDX, slen;
				mov EBX, fd;
				mov EAX, 4; // sys_write
				int 0x80;
			}
			else version(D_InlineAsm_X86_64)
			asm {
				mov RSI, sptr;
				mov RDX, slen;
				mov RDI, fd;
				mov RAX, 1; // sys_write
				syscall;
			}
		}
	}

	void write(T...)(T t) {
		foreach(a; t)
			write_raw(a);
	}

	nothrow pure size_t strlen(const(char)* c) {
		if(c is null)
			return 0;

		size_t l = 0;
		while(*c) {
			c++;
			l++;
		}
		return l;
	}

	void main() {}
	extern(C) int kmain(uint magic, ulong info);
	int callKmain(uint magic, ulong info) {
		try {
			return kmain(magic, info);
		} catch(Throwable t) {
			write("\n**UNCAUGHT EXCEPTION**\n");
			t.print();
			manual_free(t);
			return (1);
		}
	}

	version(with_libc) {
		string[] environment;
		extern(C) int main(int argc, immutable(char**) argv) {
			string[256] args = void;
			foreach(i; 0 .. argc) {
				auto cstr = argv[i];
				void* dstr = cast(void*) &(args[i]);
				* cast(size_t*) (dstr + 0 ) = strlen(cstr);
				* cast(immutable(char)**) (dstr + size_t.sizeof ) = cstr;
			}

			return callDmain(args);
		}
	} else {
		__gshared string[] environment;

		version(bare_metal)
		extern(C) void _Dkmain_entry(uint magic, ulong info) {
			exit(callKmain(magic, info));
		}
		else
		extern(C) void _Dmain_entry(size_t* argsAddress) {
			size_t argc = * argsAddress;

			auto argv = cast(immutable(char**))(argsAddress + 1);
			string[256] args = void;
			foreach(i; 0 .. argc) {
				auto cstr = argv[i];
				void* dstr = cast(void*) &(args[i]);
				* cast(size_t*) (dstr + 0 ) = strlen(cstr);
				* cast(immutable(char)**) (dstr + size_t.sizeof ) = cstr;
			}
			int envc;

			auto envp = argc;

			if(argv[envp] !is null)
				exit(255); // wtf? this should be the terminator of argv...
			envp++;

			string[256] environment = void;
			while(argv[envp]) {
				auto cstr = argv[envp];
				void* dstr = cast(void*) &(environment[envc]);
				* cast(size_t*) (dstr + 0 ) = strlen(cstr);
				* cast(immutable(char)**) (dstr + size_t.sizeof ) = cstr;

				envp++;
				envc++;
				if(envc >= environment.length) {
					write_raw("too much environment", 2);
					exit(254);
					assert(0); // not reached
				}
			}

			.environment = environment[0 .. envc];

			exit(callDmain(args[0..argc]));
		}
	}

	void exit(ssize_t code = 0) {
		debug(allocations) {
			write("\n", totalAllocations, " total allocations\n");
			if(allocations)
				write("warning, terminating with ", allocations, " pieces of still allocated memory\n");
			else
				write("all freed!\n");
		}

		version(bare_metal)
		asm {
			cli;
			stay_dead:
			hlt;
			jmp stay_dead;
		}
		else version(D_InlineAsm_X86)
		asm {
			mov EAX, 1; // sys_exit
			mov EBX, code;
			int 0x80;
		}
		else version(D_InlineAsm_X86_64)
		asm {
			mov RAX, 60; // sys_exit
			mov RDI, code;
			syscall;
		}
	}
}

version(bare_metal)
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

extern(C) {
	// the compiler spits this out all the time

	Object _d_newclass(const ClassInfo ci) {
		void* memory = manual_malloc(ci.init.length);
		if(memory is null) {
			write("\n\n_d_newclass malloc failure\n\n");
			exit();
		}

		(cast(byte*) memory)[0 .. ci.init.length] = ci.init[];
		return cast(Object) memory;
	}

	//void* _d_newarrayT

	// and these came when I started using foreach
	void _d_unittestm(string file, uint line) {
		write("_d_unittest_");
		exit(1);
	}
	void _d_array_bounds(ModuleInfo* m, uint line) {
		_d_arraybounds(m.name, line);
	}
	void _d_arraybounds(string m, uint line) {
		version(without_exceptions) {
			write("_d_array_bounds");
			exit(1);
		} else {
			throw new Error("Range error", m, line);
		}
	}
	void _d_unittest() { }
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
		version(without_exceptions) {
			write("\nAssertion failure\n");
			exit(1);
		} else {
			throw new AssertError(msg, file, line);
		}
	}
}

char[] intToString(ssize_t i, char[] buffer) {
	ssize_t pos = buffer.length - 1;

	if(i == 0) {
		buffer[pos] = '0';
		pos--;
	}

	while(pos > 0 && i) {
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
// FIXME: what's the proper 32 bit version?
version(D_InlineAsm_X86) {
	alias uint size_t;
	alias uint sizediff_t;
	alias int ptrdiff_t;
	alias int ssize_t;
} else version(D_InlineAsm_X86_64) {
	alias ulong size_t;
	alias ulong sizediff_t;
	alias long ptrdiff_t;
	alias long ssize_t;
}

/* ******************************** */
/*          Basic D classes         */
/* ******************************** */


bool opEquals(const Object lhs, const Object rhs)
{
    // A hack for the moment.
    return lhs is rhs;
}



class Object {
	string toString() const { return ""; } // for D
	bool opEquals(Object rhs) { return rhs is this; }

    bool opEquals(Object lhs, Object rhs)
    {
        if (lhs is rhs)
            return true;
        if (lhs is null || rhs is null)
            return false;
        if (typeid(lhs) == typeid(rhs))
            return lhs.opEquals(rhs);
        return lhs.opEquals(rhs) &&
               rhs.opEquals(lhs);
    }


    	int opCmp(Object o) { return 0; }
    	size_t toHash() nothrow @trusted const { return cast(size_t) &this; }
}
class Throwable : Object { // required by the D compiler

    interface TraceInfo
    {
        int opApply(scope int delegate(ref const(char[]))) const;
        int opApply(scope int delegate(ref size_t, ref const(char[]))) const;
        string toString() const;
    }

    Throwable next;

    ~this() {
	if(next !is null)
		manual_free(next);
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
		write(this.classinfo.name, "@", file, "(", line, "): ", message, "\n");
	}
}
class Error : Throwable { // required by the D compiler
	Throwable bypassedException;
	this(string msg, string file = __FILE__, size_t line = __LINE__) {
		super(msg, file, line);
	}

	~this() {
		if(bypassedException !is null)
			manual_free(bypassedException);
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
	typeof(this) dup() { return this; } // FIXME
}
class TypeInfo {
    @property immutable(MoreTypeInfo*) rtInfo() nothrow pure const @safe { return null; }
        /// Returns a hash of the instance of a type.
    size_t getHash(in void* p) @trusted nothrow const { return cast(size_t)p; }

    /// Compares two instances for equality.
    bool equals(in void* p1, in void* p2) const { return p1 == p2; }

    /// Compares two instances for &lt;, ==, or &gt;.
    int compare(in void* p1, in void* p2) const { return 0; }

    /// Returns size of the type.
    @property size_t tsize() nothrow pure const @safe { return 0; }


    /// Swaps two instances of the type.
    void swap(void* p1, void* p2) const
    {
        size_t n = tsize;
        for (size_t i = 0; i < n; i++)
        {
            byte t = (cast(byte *)p1)[i];
            (cast(byte*)p1)[i] = (cast(byte*)p2)[i];
            (cast(byte*)p2)[i] = t;
        }
    }

    /// Get TypeInfo for 'next' type, as defined by what kind of type this is,
    /// null if none.
    /// Get type information on the contents of the type; null if not available
    const(OffsetTypeInfo)[] offTi() const { return null; }
    /// Run the destructor on the object and all its sub-objects
    void destroy(void* p) const {}
    /// Run the postblit on the object and all its sub-objects
    void postblit(void* p) const {}


	//byte[] init() { return  null;}

    override size_t toHash() @trusted const
    {
        try
        {
		//import rt.util.hash;
            auto data = this.toString();
            //return hashOf(data.ptr, data.length);
	    return 0;
        }
        catch (Throwable)
        {
            // This should never happen; remove when toString() is made nothrow

            // BUG: this prevents a compacting GC from working, needs to be fixed
            return cast(size_t)cast(void*)this;
        }
    }

    override int opCmp(Object o)
    {
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
    @property size_t talign() nothrow pure const @safe { return tsize; }


    @property const(TypeInfo) next() nothrow pure const { return null; }

    const(void)[] init() nothrow pure const @safe { return null; }

    /// Get flags for type: 1 means GC should scan for pointers
    @property uint flags() nothrow pure const @safe { return 0; }



}

class TypeInfo_StaticArray : TypeInfo {
	TypeInfo value;
	size_t len;
}

class TypeInfo_Function : TypeInfo {
	TypeInfo next;
	string deco;
}


class TypeInfo_Interface : TypeInfo
{
    override string toString() const { return info.name; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Interface)o;
        return c && this.info.name == c.classinfo.name;
    }

    override size_t getHash(in void* p) @trusted const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p;
        Object o = cast(Object)(*cast(void**)p - pi.offset);
        assert(o);
        return o.toHash();
    }

    override bool equals(in void* p1, in void* p2) const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);

        return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }

    override int compare(in void* p1, in void* p2) const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);
        int c = 0;

        // Regard null references as always being "less than"
        if (o1 != o2)
        {
            if (o1)
            {
                if (!o2)
                    c = 1;
                else
                    c = o1.opCmp(o2);
            }
            else
                c = -1;
        }
        return c;
    }

    override @property size_t tsize() nothrow pure const
    {
        return Object.sizeof;
    }

    override @property uint flags() nothrow pure const { return 1; }

    TypeInfo_Class info;
}


class TypeInfo_Class : TypeInfo {

    byte[]      init;           /** class static initializer
                                 * (init.length gives size in bytes of class)
                                 */
    string      name;           /// class name
    void*[]     vtbl;           /// virtual function pointer table
    Interface[] interfaces;     /// interfaces this class implements
    TypeInfo_Class   base;           /// base class
    void*       destructor;
    void function(Object) classInvariant;
    uint        m_flags;
    //  1:                      // is IUnknown or is derived from IUnknown
    //  2:                      // has no possible pointers into GC memory
    //  4:                      // has offTi[] member
    //  8:                      // has constructors
    // 16:                      // has xgetMembers member
    // 32:                      // has typeinfo member
    // 64:                      // is not constructable
    void*       deallocator;
    OffsetTypeInfo[] m_offTi;
    void function(Object) defaultConstructor;   // default Constructor

    immutable(MoreTypeInfo*) m_RTInfo;        // data for precise GC
    override @property immutable(MoreTypeInfo*) rtInfo() nothrow pure @safe const { return m_RTInfo; }

}

version(without_custom_runtime_reflection) {
	// NOTE: don't actually use any of these
	class TypeInfo_A : TypeInfo {}
	class TypeInfo_i : TypeInfo {}
	class TypeInfo_Aya : TypeInfo {}
	class TypeInfo_Aa : TypeInfo {}
	class TypeInfo_Ai : TypeInfo {}
	class TypeInfo_m : TypeInfo {}
	class TypeInfo_g : TypeInfo {}
	class TypeInfo_v : TypeInfo {}
	class TypeInfo_l : TypeInfo {}
} else {
	mixin(makeTypeInfo!(char, wchar, dchar, int, uint, short, ushort, byte, ubyte, long, ulong, float, double, real, void, bool, string)());

	private string makeTypeInfo(T...)() {
		if(__ctfe) {
		string code;

		void doit(t)() {
			if(__ctfe) {
				code ~= "class TypeInfo_" ~ t.mangleof ~ " : TypeInfo {
					override string toString() const { return \""~t.stringof~"\"; }
				}";
			}
		}

		foreach(t; T) {
			doit!(t)();
			doit!(t[])();
		}
		return code;
		} else assert(0);
	}


}
class TypeInfo_AC : TypeInfo {}
class TypeInfo_Pointer : TypeInfo { void* stuff;}
class TypeInfo_Array : TypeInfo { void* whatever; }
class TypeInfo_Const : TypeInfo { void* whatever; }
class TypeInfo_Invariant : TypeInfo_Const {}
class TypeInfo_Shared : TypeInfo_Const {}
class TypeInfo_Enum : TypeInfo { void*[5] stuff; }
class TypeInfo_Inout : TypeInfo_Const {}
class TypeInfo_Struct : TypeInfo {
	version(D_InlineAsm_X86)
		void*[13] stuff;
	else version(D_InlineAsm_X86_64)
		void*[15] stuff;
}
alias TypeInfo_Class ClassInfo;

struct Interface
{
    TypeInfo_Class   classinfo;  /// .classinfo for this interface (not for containing class)
    void*[]     vtbl;
    ptrdiff_t   offset;     /// offset to Interface 'this' from Object 'this'
}


/**
 * Array of pairs giving the offset and type information for each
 * member in an aggregate.
 */
struct OffsetTypeInfo
{
    size_t   offset;    /// Offset of member from start of object
    TypeInfo ti;        /// TypeInfo for this member
}


version(without_custom_runtime_reflection) {
	template RTInfo(T) {
		enum RTInfo = null;
	}

	alias void MoreTypeInfo;
} else {
	struct MoreTypeInfo {
		hash_t hash;
		string stringOf;

		immutable(void)* userRtInfo;
		immutable(CustomTypeInfoExtension)[] customInfo;

		immutable(T)* getCustomInfo(T)() immutable {
			auto hash = typeid(T); // typehash!T;
			foreach(ci; customInfo) {
				if(ci.typeOfData == hash)
					return cast(immutable(T)*) ci.data();
			}
			return null;
		}
	}

	struct CustomTypeInfoExtension {
		TypeInfo typeOfData;
		void* function() data;
	}

	immutable(CustomTypeInfoExtension)[] getCustomInfoInternal(T)() {
		if(__ctfe) {
			//bool[hash_t] seen;
			immutable(CustomTypeInfoExtension)[] ext;
			foreach(attr; __traits(getAttributes, T))
				static if(is(typeof(attr) == CustomTypeInfoExtension)) {
					//auto hash = attr.typeOfData.rtInfo.hash;
					//if(hash in seen)
						//assert(0, "repeated data");
					//seen[hash] = true;
					ext ~= cast(immutable) attr;
				}
			return ext;
		} else return null;
	}


	template CustomInfo(alias T) {
		__gshared static data = T;
		void* getRaw() { return cast(void*) &data; }
		enum CustomInfo = CustomTypeInfoExtension( typeid(typeof(data))/*typehash!(typeof(data))*/, &getRaw);
	}

	template urtInfo(T) {
		static if (__traits(compiles, { auto a = cast(immutable(void)*) T.userRtInfo!T; }))
			enum urtInfo = cast(immutable(void)*) T.userRtInfo!T;
		else
			enum urtInfo = null;
	}

	enum CustomCtCheckResult {
		fail, pass
	}
	template CustomCheck(alias C) {
		template CustomCheck(T) {
			static if(__traits(compiles, C!T))
				enum CustomCheck = CustomCtCheckResult.pass;
			else
				enum CustomCheck = CustomCtCheckResult.fail;
		}
	}

	bool doCustomChecks(T)() {
		if(__ctfe) {
			foreach(attr; __traits(getAttributes, T)) {
				static if(is(typeof(attr!T) == CustomCtCheckResult)) {
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
		__gshared static immutable minfo = MoreTypeInfo(typehash!T, T.stringof, urtInfo!T
			, getCustomInfoInternal!T);

		enum customChecksPassed = doCustomChecks!T;

		enum RTInfo = &minfo;
	}
}

extern(C) __gshared void* _Dmodule_ref;

extern(C) byte[] _d_arraycopy(size_t size, byte[] from, byte[] to)
{
	if (to.length != from.length)
	{
		version(without_exceptions)
			exit(2);
		else
			throw new Exception("lengths don't match for array copy");
	}
	else if (to.ptr + to.length * size <= from.ptr ||
			from.ptr + from.length * size <= to.ptr)
	{
		version(with_libc) {
			memcpy(to.ptr, from.ptr, to.length * size);
		} else {
			size_t s = to.length * size;
			byte* b1 = from.ptr;
			byte* b2 = to.ptr;
			while(s) {
				*b2 = *b1;
				++b2;
				++b1;
				--s;
			}
		}
	}
	else
	{
		version(without_exceptions)
			exit(2);
		else
			throw new Exception("overlapping array copy");
	}
	return to;
}

extern(C) ssize_t _d_switch_string(char[][] table, char[] it) {
	foreach(i, item; table)
		if(item == it)
			return i;
	return -1;
}

// these byte[] are supposed to be void[]
extern(C) int _adEq2(byte[] a1, byte[] a2, TypeInfo ti) {
	if(a1.length != a2.length)
		return 0;
	for(int a = 0; a < a1.length; a++)
		if(a1[a] != a2[a])
			return 0;
	return 1;
}

__gshared ubyte[1024 * 1024] heap = void;
__gshared int heapPosition = 0;

// immutable allocs are on a special heap that are never freed
// so you should use sparingly
immutable(T)[] immutable_alloc(T)(T[] dataToCopy) {
	return null;
}

immutable(T)[] immutable_alloc(T)(scope void delegate(T[]) initalizer) {
	return null;
}

debug(allocations) {
	__gshared int allocations = 0;
	__gshared int totalAllocations = 0;
}

void* manual_malloc(size_t bytes) {
	void* ret;
	version(use_malloc)
		ret = malloc(bytes);
	else {
		auto place = heap[heapPosition .. heapPosition + bytes];
		heapPosition += bytes;
		ret = place.ptr;
	}

	debug(allocations) {
		write("ALLOCATION: ", cast(size_t) ret, "\n");
		allocations++;
		totalAllocations++;
	}

	return ret;
}

void* manual_realloc(void* memory, size_t newCapacity) {
	version(use_malloc)
		return realloc(memory, newCapacity);

	if(newCapacity == 0) {
		manual_free(memory);
		return null;
	}
	if(memory is null)
		return manual_malloc(newCapacity);
	assert(0);
}

void manual_free(void* memory) {
	debug(allocations) {
		write("FREED: ", cast(size_t) memory, "\n");
		allocations--;
	}

	version(use_malloc) {
		free(memory);
		return;
	}
}

void manual_free(Object object) {
	auto dtor = cast(void function(Object o)) object.classinfo.destructor;
	if(dtor)
		dtor(object);
	manual_free(cast(void*) object);
}

// this would be used for automatic heap closures, but there's no way to free it...
///*
extern(C)
void* _d_allocmemory(size_t bytes) {
	auto ptr = manual_malloc(bytes);
	debug(allocations) {
		char[16] buffer;
		write("warning: automatic memory allocation ", intToString(cast(size_t) ptr, buffer));
	}
	return ptr;
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

Object _d_toObject(void* p)
{   Object o;

    if (p)
    {
        o = cast(Object)p;
        ClassInfo oc = o.classinfo;
        Interface *pi = **cast(Interface ***)p;

        /* Interface.offset lines up with ClassInfo.name.ptr,
         * so we rely on pointers never being less than 64K,
         * and Objects never being greater.
         */
        if (pi.offset < 0x10000)
        {
            o = cast(Object)(p - pi.offset);
        }
    }
    return o;
}


/*************************************
 * Attempts to cast Object o to class c.
 * Returns o if successful, null if not.
 */

Object _d_interface_cast(void* p, ClassInfo c)
{   Object o;

    if (p)
    {
        Interface *pi = **cast(Interface ***)p;

        o = cast(Object)(p - pi.offset);
        return _d_dynamic_cast(o, c);
    }
    return o;
}

Object _d_dynamic_cast(Object o, ClassInfo c)
{   ClassInfo oc;
    size_t offset = 0;


    if (o)
    {
        oc = o.classinfo;
        if (_d_isbaseof2(oc, c, offset))
        {
            o = cast(Object)(cast(void*)o + offset);
        }
        else
            o = null;
    }
    return o;
}

int _d_isbaseof2(ClassInfo oc, ClassInfo c, ref size_t offset)
{
    if (oc is c)
        return 1;
    do
    {
        if (oc.base is c)
            return 1;
        foreach (i; 0..oc.interfaces.length)
        {
            auto ic = oc.interfaces[i].classinfo;
            if (ic is c)
            {   offset = oc.interfaces[i].offset;
                return 1;
            }
        }
        foreach (i; 0..oc.interfaces.length)
        {
            auto ic = oc.interfaces[i].classinfo;
            if (_d_isbaseof2(ic, c, offset))
            {   offset = oc.interfaces[i].offset;
                return 1;
            }
        }
        oc = oc.base;
    } while (oc);
    return 0;
}

int _d_isbaseof(ClassInfo oc, ClassInfo c)
{
    if (oc is c)
        return 1;
    do
    {
        if (oc.base is c)
            return 1;
        foreach (i; 0..oc.interfaces.length)
        {
            auto ic = oc.interfaces[i].classinfo;
            if (ic is c || _d_isbaseof(ic, c))
                return 1;
        }
        oc = oc.base;
    } while (oc);
    return 0;
}

/*********************************
 * Find the vtbl[] associated with Interface ic.
 */

void *_d_interface_vtbl(ClassInfo ic, Object o)
{

    assert(o);

    auto oc = o.classinfo;
    foreach (i; 0..oc.interfaces.length)
    {
        auto oic = oc.interfaces[i].classinfo;
        if (oic is ic)
        {
            return cast(void *)oc.interfaces[i].vtbl;
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

 version(without_exceptions) {} else {

version (Posix)
{
    version = deh2;
}
else version (Win64)
{
    version = deh2;
}
}

// Use deh.d for Win32

version (deh2)
{

//debug=1;
//debug import core.stdc.stdio : printf;

extern (C)
{
    Throwable.TraceInfo _d_traceContext(void* ptr = null);

    int _d_isbaseof(ClassInfo oc, ClassInfo c);

    void _d_createTrace(Object*) {}
}

alias int function() fp_t;   // function pointer in ambient memory model

// DHandlerInfo table is generated by except_gentables() in eh.c

struct DHandlerInfo
{
    uint offset;                // offset from function address to start of guarded section
    uint endoffset;             // offset of end of guarded section
    int prev_index;             // previous table index
    uint cioffset;              // offset to DCatchInfo data from start of table (!=0 if try-catch)
    size_t finally_offset;      // offset to finally code to execute
                                // (!=0 if try-finally)
}

// Address of DHandlerTable, searched for by eh_finddata()

struct DHandlerTable
{
    uint espoffset;             // offset of ESP from EBP
    uint retoffset;             // offset from start of function to return code
    size_t nhandlers;           // dimension of handler_info[] (use size_t to set alignment of handler_info[])
    DHandlerInfo handler_info[1];
}

struct DCatchBlock
{
    ClassInfo type;             // catch type
    size_t bpoffset;            // EBP offset of catch var
    size_t codeoffset;          // catch handler offset
}

// Create one of these for each try-catch
struct DCatchInfo
{
    size_t ncatches;                    // number of catch blocks
    DCatchBlock catch_block[1];         // data for each catch block
}

// One of these is generated for each function with try-catch or try-finally

struct FuncTable
{
    void *fptr;                 // pointer to start of function
    DHandlerTable *handlertable; // eh data for this function
    uint fsize;         // size of function in bytes
}

private
{
    struct InFlight
    {
        InFlight*   next;
        void*       addr;
        Throwable   t;
    }

    __gshared InFlight* __inflight = null;
}

void terminate()
{
	write("Uncaught exception or busted up stack\n");
	exit();
}

FuncTable *__eh_finddata(void *address)
{
    auto pstart = cast(FuncTable *)&_deh_beg;
    auto pend   = cast(FuncTable *)&_deh_end;

    for (auto ft = pstart; 1; ft++)
    {
     Lagain:
        if (ft >= pend)
            break;

        version (Win64)
        {
            /* The MS Linker has an inexplicable and erratic tendency to insert
             * 8 zero bytes between sections generated from different .obj
             * files. This kludge tries to skip over them.
             */
            if (ft.fptr == null)
            {
                ft = cast(FuncTable *)(cast(void**)ft + 1);
                goto Lagain;
            }
        }

        void *fptr = ft.fptr;
        version (Win64)
        {
            /* If linked with /DEBUG, the linker rewrites it so the function pointer points
             * to a JMP to the actual code. The address will be in the actual code, so we
             * need to follow the JMP.
             */
            if ((cast(ubyte*)fptr)[0] == 0xE9)
            {   // JMP target = RIP of next instruction + signed 32 bit displacement
                fptr = fptr + 5 + *cast(int*)(fptr + 1);
            }
        }

        if (fptr <= address &&
            address < cast(void *)(cast(char *)fptr + ft.fsize))
        {
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

size_t __eh_find_caller(size_t regbp, size_t *pretaddr)
{
    size_t bp = *cast(size_t *)regbp;

    if (bp)         // if not end of call chain
    {
        // Perform sanity checks on new EBP.
        // If it is screwed up, terminate() hopefully before we do more damage.
        if (bp <= regbp)
            // stack should grow to smaller values
            terminate();

        *pretaddr = *cast(size_t *)(regbp + size_t.sizeof);
    }
    return bp;
}


/***********************************
 * Throw a D object.
 */

version(without_exceptions) {} else
extern (C) void _d_throwc(Object *h)
{
    size_t regebp;

    debug
    {
    }

    version (D_InlineAsm_X86)
        asm
        {
            mov regebp,EBP  ;
        }
    else version (D_InlineAsm_X86_64)
        asm
        {
            mov regebp,RBP  ;
        }
    else
        static assert(0);

    _d_createTrace(h);

//static uint abc;
//if (++abc == 2) *(char *)0=0;

//int count = 0;
    while (1)           // for each function on the stack
    {
        size_t retaddr;

        regebp = __eh_find_caller(regebp,&retaddr);
        if (!regebp)
        {   // if end of call chain
            break;
        }

//if (++count == 12) *(char*)0=0;
        auto func_table = __eh_finddata(cast(void *)retaddr);   // find static data associated with function
        auto handler_table = func_table ? func_table.handlertable : null;
        if (!handler_table)         // if no static data
        {
            continue;
        }
        auto funcoffset = cast(size_t)func_table.fptr;
        version (Win64)
        {
            /* If linked with /DEBUG, the linker rewrites it so the function pointer points
             * to a JMP to the actual code. The address will be in the actual code, so we
             * need to follow the JMP.
             */
            if ((cast(ubyte*)funcoffset)[0] == 0xE9)
            {   // JMP target = RIP of next instruction + signed 32 bit displacement
                funcoffset = funcoffset + 5 + *cast(int*)(funcoffset + 1);
            }
        }
        auto spoff = handler_table.espoffset;
        auto retoffset = handler_table.retoffset;

        // Find start index for retaddr in static data
        auto dim = handler_table.nhandlers;

        auto index = -1;
        for (int i = 0; i < dim; i++)
        {
            auto phi = &handler_table.handler_info.ptr[i];

            if (retaddr > funcoffset + phi.offset &&
                retaddr <= funcoffset + phi.endoffset)
                index = i;
        }

        if (dim)
        {
            auto phi = &handler_table.handler_info.ptr[index+1];
            auto prev = cast(InFlight*)
	    	&__inflight;
            auto curr = prev.next;

            if (curr !is null && curr.addr == cast(void*)(funcoffset + phi.finally_offset))
            {
                auto e = cast(Error)(cast(Throwable) h);
                if (e !is null && (cast(Error) curr.t) is null)
                {

                    e.bypassedException = curr.t;
                    prev.next = curr.next;
                    //h = cast(Object*) t;
                }
                else
                {

                    auto t = curr.t;
                    auto n = curr.t;

                    while (n.next)
                        n = n.next;
                    n.next = cast(Throwable) h;
                    prev.next = curr.next;
                    h = cast(Object*) t;
                }
            }
        }

        // walk through handler table, checking each handler
        // with an index smaller than the current table_index
        int prev_ndx;
        for (auto ndx = index; ndx != -1; ndx = prev_ndx)
        {
            auto phi = &handler_table.handler_info.ptr[ndx];
            prev_ndx = phi.prev_index;
            if (phi.cioffset)
            {
                // this is a catch handler (no finally)

                auto pci = cast(DCatchInfo *)(cast(char *)handler_table + phi.cioffset);
                auto ncatches = pci.ncatches;
                for (int i = 0; i < ncatches; i++)
                {
                    auto ci = **cast(ClassInfo **)h;

                    auto pcb = &pci.catch_block.ptr[i];

                    if (_d_isbaseof(ci, pcb.type))
                    {
                        // Matched the catch type, so we've found the handler.

                        // Initialize catch variable
                        *cast(void **)(regebp + (pcb.bpoffset)) = h;

                        // Jump to catch block. Does not return.
                        {
                            size_t catch_esp;
                            fp_t catch_addr;

                            catch_addr = cast(fp_t)(funcoffset + pcb.codeoffset);
                            catch_esp = regebp - handler_table.espoffset - fp_t.sizeof;
                            version (D_InlineAsm_X86)
                                asm
                                {
                                    mov     EAX,catch_esp   ;
                                    mov     ECX,catch_addr  ;
                                    mov     [EAX],ECX       ;
                                    mov     EBP,regebp      ;
                                    mov     ESP,EAX         ; // reset stack
                                    ret                     ; // jump to catch block
                                }
                            else version (D_InlineAsm_X86_64)
                                asm
                                {
                                    mov     RAX,catch_esp   ;
                                    mov     RCX,catch_esp   ;
                                    mov     RCX,catch_addr  ;
                                    mov     [RAX],RCX       ;
                                    mov     RBP,regebp      ;
                                    mov     RSP,RAX         ; // reset stack
                                    ret                     ; // jump to catch block
                                }
                            else
                                static assert(0);
                        }
                    }
                }
            }
            else if (phi.finally_offset)
            {
                // Call finally block
                // Note that it is unnecessary to adjust the ESP, as the finally block
                // accesses all items on the stack as relative to EBP.

                auto     blockaddr = cast(void*)(funcoffset + phi.finally_offset);
                InFlight inflight;

                inflight.addr = blockaddr;
                inflight.next = __inflight;
                inflight.t    = cast(Throwable) h;
                __inflight    = &inflight;

                version (OSX)
                {
                    version (D_InlineAsm_X86)
                        asm
                        {
                            sub     ESP,4           ;
                            push    EBX             ;
                            mov     EBX,blockaddr   ;
                            push    EBP             ;
                            mov     EBP,regebp      ;
                            call    EBX             ;
                            pop     EBP             ;
                            pop     EBX             ;
                            add     ESP,4           ;
                        }
                    else version (D_InlineAsm_X86_64)
                        asm
                        {
                            sub     RSP,8           ;
                            push    RBX             ;
                            mov     RBX,blockaddr   ;
                            push    RBP             ;
                            mov     RBP,regebp      ;
                            call    RBX             ;
                            pop     RBP             ;
                            pop     RBX             ;
                            add     RSP,8           ;
                        }
                    else
                        static assert(0);
                }
                else
                {
                    version (D_InlineAsm_X86)
                        asm
                        {
                            push    EBX             ;
                            mov     EBX,blockaddr   ;
                            push    EBP             ;
                            mov     EBP,regebp      ;
                            call    EBX             ;
                            pop     EBP             ;
                            pop     EBX             ;
                        }
                    else version (D_InlineAsm_X86_64)
                        asm
                        {
                            sub     RSP,8           ;
                            push    RBX             ;
                            mov     RBX,blockaddr   ;
                            push    RBP             ;
                            mov     RBP,regebp      ;
                            call    RBX             ;
                            pop     RBP             ;
                            pop     RBX             ;
                            add     RSP,8           ;
                        }
                    else
                        static assert(0);
                }

                if (__inflight is &inflight)
                    __inflight = __inflight.next;
            }
        }
    }
    terminate();
}

}


version(without_moduleinfo) {
	struct ModuleInfo {
		static string name() { return "<no_moduleinfo>"; }
	}
} else {
	///////////////////////////////////////////////////////////////////////////////
	// ModuleInfo
	///////////////////////////////////////////////////////////////////////////////


	enum
	{
	    MIctorstart  = 0x1,   // we've started constructing it
	    MIctordone   = 0x2,   // finished construction
	    MIstandalone = 0x4,   // module ctor does not depend on other module
	                        // ctors being done first
	    MItlsctor    = 8,
	    MItlsdtor    = 0x10,
	    MIctor       = 0x20,
	    MIdtor       = 0x40,
	    MIxgetMembers = 0x80,
	    MIictor      = 0x100,
	    MIunitTest   = 0x200,
	    MIimportedModules = 0x400,
	    MIlocalClasses = 0x800,
	    MIname       = 0x1000,
	}


	struct ModuleInfo
	{
	    uint _flags;
	    uint _index; // index into _moduleinfo_array[]

	    version (all)
	    {
	        deprecated("ModuleInfo cannot be copy-assigned because it is a variable-sized struct.")
	        void opAssign(in ModuleInfo m) { _flags = m._flags; _index = m._index; }
	    }
	    else
	    {
	        @disable this();
	        @disable this(this) const;
	    }

	const:
	    private void* addrOf(int flag) nothrow pure
	    in
	    {
	        assert(flag >= MItlsctor && flag <= MIname);
	        assert(!(flag & (flag - 1)) && !(flag & ~(flag - 1) << 1));
	    }
	    body
	    {
	        void* p = cast(void*)&this + ModuleInfo.sizeof;

	        if (flags & MItlsctor)
	        {
	            if (flag == MItlsctor) return p;
	            p += typeof(tlsctor).sizeof;
	        }
	        if (flags & MItlsdtor)
	        {
	            if (flag == MItlsdtor) return p;
	            p += typeof(tlsdtor).sizeof;
	        }
	        if (flags & MIctor)
	        {
	            if (flag == MIctor) return p;
	            p += typeof(ctor).sizeof;
	        }
	        if (flags & MIdtor)
	        {
	            if (flag == MIdtor) return p;
	            p += typeof(dtor).sizeof;
	        }
	        if (flags & MIxgetMembers)
	        {
	            if (flag == MIxgetMembers) return p;
	            p += typeof(xgetMembers).sizeof;
	        }
	        if (flags & MIictor)
	        {
	            if (flag == MIictor) return p;
	            p += typeof(ictor).sizeof;
	        }
	        if (flags & MIunitTest)
	        {
	            if (flag == MIunitTest) return p;
	            p += typeof(unitTest).sizeof;
	        }
	        if (flags & MIimportedModules)
	        {
	            if (flag == MIimportedModules) return p;
	            p += size_t.sizeof + *cast(size_t*)p * typeof(importedModules[0]).sizeof;
	        }
	        if (flags & MIlocalClasses)
	        {
	            if (flag == MIlocalClasses) return p;
	            p += size_t.sizeof + *cast(size_t*)p * typeof(localClasses[0]).sizeof;
	        }
	        if (true || flags & MIname) // always available for now
	        {
	            if (flag == MIname) return p;
	            p += strlen(cast(immutable char*)p);
	        }
	        assert(0);
	    }

	    @property uint index() nothrow pure { return _index; }

	    @property uint flags() nothrow pure { return _flags; }

	    @property void function() tlsctor() nothrow pure
	    {
	        return flags & MItlsctor ? *cast(typeof(return)*)addrOf(MItlsctor) : null;
	    }

	    @property void function() tlsdtor() nothrow pure
	    {
	        return flags & MItlsdtor ? *cast(typeof(return)*)addrOf(MItlsdtor) : null;
	    }

	    @property void* xgetMembers() nothrow pure
	    {
	        return flags & MIxgetMembers ? *cast(typeof(return)*)addrOf(MIxgetMembers) : null;
	    }

	    @property void function() ctor() nothrow pure
	    {
	        return flags & MIctor ? *cast(typeof(return)*)addrOf(MIctor) : null;
	    }

	    @property void function() dtor() nothrow pure
	    {
	        return flags & MIdtor ? *cast(typeof(return)*)addrOf(MIdtor) : null;
	    }

	    @property void function() ictor() nothrow pure
	    {
	        return flags & MIictor ? *cast(typeof(return)*)addrOf(MIictor) : null;
	    }

	    @property void function() unitTest() nothrow pure
	    {
	        return flags & MIunitTest ? *cast(typeof(return)*)addrOf(MIunitTest) : null;
	    }

	    @property immutable(ModuleInfo*)[] importedModules() nothrow pure
	    {
	        if (flags & MIimportedModules)
	        {
	            auto p = cast(size_t*)addrOf(MIimportedModules);
	            return (cast(immutable(ModuleInfo*)*)(p + 1))[0 .. *p];
	        }
	        return null;
	    }

	    @property TypeInfo_Class[] localClasses() nothrow pure
	    {
	        if (flags & MIlocalClasses)
	        {
	            auto p = cast(size_t*)addrOf(MIlocalClasses);
	            return (cast(TypeInfo_Class*)(p + 1))[0 .. *p];
	        }
	        return null;
	    }

	    @property string name() nothrow pure
	    {
	        if (true || flags & MIname) // always available for now
	        {
	            auto p = cast(immutable char*)addrOf(MIname);
	            return p[0 .. strlen(p)];
	        }
	        // return null;
	    }

			alias extern(D) int delegate(ref ModuleInfo*) ApplyDg;

	    version(without_custom_runtime_reflection) {} else
	    static int opApply(scope ApplyDg dg)
	    {
	    	ModuleInfo** start;
				ModuleInfo** end;
	    	version(compiler_dso) {
					start = cast(ModuleInfo**) _minfo_beg;
					end = cast(ModuleInfo**) _minfo_end;
				} else {
						// needed a linker hack here, commends see below
					start = cast(ModuleInfo**) &_minfo_beg;
					end = cast(ModuleInfo**) &_minfo_end;

				}

				while(start != end) {
					auto m = *start;
					if(m !is null) {
						if(auto res = dg(m)) return res;
					}
					start++;
				}
				return 0;
	    }
		}
	}


		/* moved from version(compiler_dso) below */
		__gshared void* _minfo_beg;
		__gshared void* _minfo_end;
		__gshared immutable(void)* _deh_beg;
		__gshared immutable(void)* _deh_end;
		struct CompilerDSOData
		{
		    size_t _version;
		    void** _slot; // can be used to store runtime data
		    object.ModuleInfo** _minfo_beg, _minfo_end;
		    immutable(void)* _deh_beg, _deh_end;
		}
		extern(C) void _d_dso_registry(CompilerDSOData* data) {
			_minfo_beg = data._minfo_beg;
			_minfo_end = data._minfo_end;
			_deh_beg = data._deh_beg;
			_deh_end = data._deh_end;
		}


version(without_custom_runtime_reflection) {} else {
	version(compiler_dso) {
	} else {
		extern(C) {
			// I had to hack this up because the _init function libc calls isn't there, so we can't get to the dso_registry that the real druntime yses. the linker script minfo.ld creates these symbols, bracketing the .minfo section.
			//extern __gshared void* _minfo_beg;
			//extern __gshared void* _minfo_end;
		}
	}
}

/* **** */
// hash function

// the following is copy/pasted from druntime src/rt/util/hash.d
// is that available as an import somewhere in the stdlib?

template typehash(T) {
	enum typehash = hashOf(T.mangleof.ptr, T.mangleof.length);
}

alias size_t hash_t;

version( X86 )
    version = AnyX86;
version( X86_64 )
    version = AnyX86;
version( AnyX86 )
    version = HasUnalignedOps;


@trusted pure nothrow
hash_t hashOf( const (void)* buf, size_t len, hash_t seed = 0 )
{
    /*
     * This is Paul Hsieh's SuperFastHash algorithm, described here:
     *   http://www.azillionmonkeys.com/qed/hash.html
     * It is protected by the following open source license:
     *   http://www.azillionmonkeys.com/qed/weblicense.html
     */
    static uint get16bits( const (ubyte)* x ) pure nothrow
    {
        // CTFE doesn't support casting ubyte* -> ushort*, so revert to
        // per-byte access when in CTFE.
        version( HasUnalignedOps )
        {
            if (!__ctfe)
                return *cast(ushort*) x;
        }

        return ((cast(uint) x[1]) << 8) + (cast(uint) x[0]);
    }

    // NOTE: SuperFastHash normally starts with a zero hash value.  The seed
    //       value was incorporated to allow chaining.
    auto data = cast(const (ubyte)*) buf;
    auto hash = seed;
    int  rem;

    if( len <= 0 || data is null )
        return 0;

    rem = len & 3;
    len >>= 2;

    for( ; len > 0; len-- )
    {
        hash += get16bits( data );
        auto tmp = (get16bits( data + 2 ) << 11) ^ hash;
        hash  = (hash << 16) ^ tmp;
        data += 2 * ushort.sizeof;
        hash += hash >> 11;
    }

    switch( rem )
    {
    case 3: hash += get16bits( data );
            hash ^= hash << 16;
            hash ^= data[ushort.sizeof] << 18;
            hash += hash >> 11;
            break;
    case 2: hash += get16bits( data );
            hash ^= hash << 11;
            hash += hash >> 17;
            break;
    case 1: hash += *data;
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

bool _xopEquals(in void*, in void*) { assert(0); }
extern(C) void _d_run_main() {}
