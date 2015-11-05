module data.util;

enum isByte(T)  = is(T == byte)  || is(T == ubyte);
enum isShort(T) = is(T == short) || is(T == ushort);
enum isInt(T)   = is(T == int)   || is(T == uint);
enum isLong(T)  = is(T == long)  || is(T == ulong);
