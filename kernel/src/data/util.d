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

template TypeTuple(T...) {
	alias TypeTuple = T;
}

template EnumMembers(E) if (is(E == enum)) {
	template WithIdentifier(string ident) {
		static if (ident == "Symbolize") {
			template Symbolize(alias value) {
				enum Symbolize = value;
			}
		} else {
			mixin("template Symbolize(alias " ~ ident ~ ")" ~ "{" ~ "alias Symbolize = " ~ ident ~ ";" ~ "}");
		}
	}

	template EnumSpecificMembers(names...) {
		static if (names.length > 0) {
			alias EnumSpecificMembers = TypeTuple!(WithIdentifier!(names[0]).Symbolize!(__traits(getMember, E,
					names[0])), EnumSpecificMembers!(names[1 .. $]));
		} else {
			alias EnumSpecificMembers = TypeTuple!();
		}
	}

	alias EnumMembers = EnumSpecificMembers!(__traits(allMembers, E));
}
