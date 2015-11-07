module data.util;

template Unqual(T) {
       static if (is(T U == shared(const U))) alias Unqual = U;
  else static if (is(T U ==        const U )) alias Unqual = U;
  else static if (is(T U ==    immutable U )) alias Unqual = U;
  else static if (is(T U ==       shared U )) alias Unqual = U;
  else                                        alias Unqual = T;
}

enum isByte(T)     = is(Unqual!T == byte)  || is(Unqual!T == ubyte);
enum isShort(T)    = is(Unqual!T == short) || is(Unqual!T == ushort);
enum isInt(T)      = is(Unqual!T == int)   || is(Unqual!T == uint);
enum isLong(T)     = is(Unqual!T == long)  || is(Unqual!T == ulong);
enum isNumber(T)   = isByte!T || isShort!T || isInt!T || isLong!T;
enum isFloating(T) = is(Unqual!T == float) || is(Unqual!T == double);
