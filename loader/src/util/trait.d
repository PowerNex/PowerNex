module util.trait;

///
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

enum isByte(T) = is(Unqual!T == byte) || is(Unqual!T == ubyte); ///
enum isShort(T) = is(Unqual!T == short) || is(Unqual!T == ushort); ///
enum isInt(T) = is(Unqual!T == int) || is(Unqual!T == uint); ///
enum isLong(T) = is(Unqual!T == long) || is(Unqual!T == ulong); ///
enum isNumber(T) = isByte!T || isShort!T || isInt!T || isLong!T; ///
enum isFloating(T) = is(Unqual!T == float) || is(Unqual!T == double); ///

enum isArray(T) = isDynamicArray!T || isStaticArray!T; ///
enum isDynamicArray(T) = is(Unqual!T : E[], E); ///
enum isStaticArray(T) = is(Unqual!T : E[n], E, size_t n); ///

enum isClass(T) = is(Unqual!T == class) || isInterface!T; ///
enum isInterface(T) = is(Unqual!T == interface); ///


///
template TypeTuple(T...) {
	alias TypeTuple = T;
}

///
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
