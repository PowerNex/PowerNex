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

// https://stackoverflow.com/a/11398748
// dfmt off
immutable int[64] tab64 = [
	63,  0, 58,  1, 59, 47, 53,  2,
	60, 39, 48, 27, 54, 33, 42,  3,
	61, 51, 37, 40, 49, 18, 28, 20,
	55, 30, 34, 11, 43, 14, 22,  4,
	62, 57, 46, 52, 38, 26, 32, 41,
	50, 36, 17, 19, 29, 10, 13, 21,
	56, 45, 25, 31, 35, 16,  9, 12,
	44, 24, 15,  8, 23,  7,  6,  5
];
//dfmt on

int log2(ulong value) {
	value |= value >> 1;
	value |= value >> 2;
	value |= value >> 4;
	value |= value >> 8;
	value |= value >> 16;
	value |= value >> 32;
	return tab64[((ulong)((value - (value >> 1)) * 0x07EDD5E59A4E28C2)) >> 58];
}
