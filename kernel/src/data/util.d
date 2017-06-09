module data.util;

template Unqual(T) {
	static if (is(T U == shared(const U)))
		alias Unqual = U;
	else static if (is(T U == const U))
		alias Unqual = U;
	else static if (is(T U == immutable U))
		alias Unqual = U;
	else static if (is(T U == shared U))
		alias Unqual = U;
	else
		alias Unqual = T;
}

enum isByte(T) = is(Unqual!T == byte) || is(Unqual!T == ubyte);
enum isShort(T) = is(Unqual!T == short) || is(Unqual!T == ushort);
enum isInt(T) = is(Unqual!T == int) || is(Unqual!T == uint);
enum isLong(T) = is(Unqual!T == long) || is(Unqual!T == ulong);
enum isNumber(T) = isByte!T || isShort!T || isInt!T || isLong!T;
enum isFloating(T) = is(Unqual!T == float) || is(Unqual!T == double);

enum isArray(T) = isDynamicArray!T || isStaticArray!T;
enum isDynamicArray(T) = is(Unqual!T : E[], E);
enum isStaticArray(T) = is(Unqual!T : E[n], E, size_t n);

template TypeTuple(T...) {
	alias TypeTuple = T;
}

template enumMembers(E) if (is(E == enum)) {
	template withIdentifier(string ident) {
		static if (ident == "Symbolize") {
			template Symbolize(alias value) {
				enum Symbolize = value;
			}
		} else {
			mixin("template Symbolize(alias " ~ ident ~ ")" ~ "{" ~ "alias Symbolize = " ~ ident ~ ";" ~ "}");
		}
	}

	template enumSpecificMembers(names...) {
		static if (names.length > 0) {
			alias enumSpecificMembers = TypeTuple!(withIdentifier!(names[0]).Symbolize!(__traits(getMember, E, names[0])),
					enumSpecificMembers!(names[1 .. $]));
		} else {
			alias enumSpecificMembers = TypeTuple!();
		}
	}

	alias enumMembers = enumSpecificMembers!(__traits(allMembers, E));
}

T inplaceClass(T, Args...)(void[] chunk, auto ref Args args) if (is(T == class)) {
	static assert(!__traits(isAbstractClass, T), T.stringof ~ " is abstract and it can't be emplaced");

	enum classSize = __traits(classInstanceSize, T);
	//assert(chunk.length >= classSize, "emplace: Chunk size too small.");
	//assert((cast(size_t)chunk.ptr) % classInstanceAlignment!T == 0, "emplace: Chunk is not aligned.");
	auto result = cast(T)chunk.ptr;

	chunk[0 .. classSize] = typeid(T).init[];

	static if (is(typeof(result.__ctor(args))))
		result.__ctor(args);
	else
		static assert(args.length == 0 && !is(typeof(&T.__ctor)),
				"Don't know how to initialize an object of type " ~ T.stringof ~ " with arguments " ~ Args.stringof);
	return result;
}

struct BinaryInt {
	ulong int_;
}

void swap(T)(ref T t1, ref T t2) {
	T tmp = t1;
	t1 = t2;
	t2 = tmp;
}

T abs(T)(T i) {
	if (i < 0)
		return -i;
	return i;
}

// https://github.com/Vild/PowerNex/commit/9db5276c34a11d86213fe7b19878762a9461f615#commitcomment-22324396
ulong log2(ulong value) {
	ulong result;
	asm pure nothrow {
		bsr RAX, value;
		mov result, RAX;
	}

	//2 ^ result == value means value is a power of 2 and we dont need to round up
	if (1 << result != value)
		result++;

	return result;
}


size_t strcpy(char[] dest, const char[] src) {
	char* pD = dest.ptr;
	const(char)* pS = src.ptr;

	size_t counter;
	while (pD && pS && *pS && counter++ < dest.length)
		*pD++ = *pS++;

	size_t ret = counter;
	while (counter++ < dest.length)
		*pD++ = '0';

	return ret;
}
