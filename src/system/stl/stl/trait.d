/**
 * Helper functions for the use in CTFE programming.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.trait;

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
template AliasSeq(T...) {
	alias AliasSeq = T;
}

/// Source: https://forum.dlang.org/post/op.vksecuhdot0hzo@las-miodowy
/// Author: Tomek Sowiński
template isVersion(string ver) {
	enum bool isVersion = !is(typeof({ mixin("version(" ~ ver ~ ") static assert(0);"); }));
}

// TODO: MOVE!!!!!!
T inplaceClass(T, Args...)(void[] chunk, auto ref Args args) if (is(T == class)) {
	static assert(!__traits(isAbstractClass, T), T.stringof ~ " is abstract and it can't be emplaced");

	enum classSize = __traits(classInstanceSize, T);
	//assert(chunk.length >= classSize, "emplace: Chunk size too small.");
	//assert((cast(size_t)chunk.ptr) % classInstanceAlignment!T == 0, "emplace: Chunk is not aligned.");
	auto result = cast(T)chunk.ptr;

	chunk[0 .. classSize] = typeid(T).initializer[];

	static if (is(typeof(result.__ctor(args))))
		result.__ctor(args);
	else
		static assert(args.length == 0 && !is(typeof(&T.__ctor)),
				"Don't know how to initialize an object of type " ~ T.stringof ~ " with arguments " ~ Args.stringof);
	return result;
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
			alias enumSpecificMembers = AliasSeq!(withIdentifier!(names[0]).Symbolize!(__traits(getMember, E, names[0])),
					enumSpecificMembers!(names[1 .. $]));
		} else {
			alias enumSpecificMembers = AliasSeq!();
		}
	}

	alias enumMembers = enumSpecificMembers!(__traits(allMembers, E));
}

/// std.meta.Filter reimplementation
template staticFilter(alias pred, TList...) {
	static if (TList.length == 0)
		alias staticFilter = AliasSeq!();
	else static if (TList.length == 1) {
		static if (pred!(TList[0]))
			alias staticFilter = AliasSeq!(TList[0]);
		else
			alias staticFilter = AliasSeq!();
	} else // '$ / 2' is used to minimize the recursion 'levels'
		alias staticFilter = AliasSeq!(staticFilter!(pred, TList[0 .. $ / 2]), staticFilter!(pred, TList[$ / 2 .. $]));
}

template staticMap(alias func, TList...) {
	static if (TList.length == 0)
		alias staticMap = AliasSeq!();
	else static if (TList.length == 1)
		alias staticMap = AliasSeq!(func!(TList[0]));
	else // '$ / 2' is used to minimize the recursion 'levels'
		alias staticMap = AliasSeq!(staticMap!(func, TList[0 .. $ / 2]), staticMap!(func, TList[$ / 2 .. $]));
}

///
template getUDAs(alias symbol, alias uda) {
	static if (is(typeof(uda))) // Is Instance
		enum isRightUDA(alias attrib) = (uda == attrib);
	else // Type
		enum isRightUDA(alias attrib) = is(uda == typeof(attrib));

	alias getUDAs = staticFilter!(isRightUDA, __traits(getAttributes, symbol));
}

///
template hasUDA(alias symbol, alias uda) {
	enum hasUDA = getUDAs!(symbol, uda).length;
}

/// Note: Symbols need to be public
template getFunctionsWithUDA(alias symbol, alias uda) {
	enum accessCheck(alias member) = __traits(compiles, __traits(getMember, symbol, member));
	alias members = staticFilter!(accessCheck, __traits(allMembers, symbol));

	alias getOverloads(alias member) = AliasSeq!(__traits(getOverloads, symbol, member));
	alias overloads = staticMap!(getOverloads, members);

	enum hasUDA(alias member) = .hasUDA!(member, uda);
	alias udaMembers = staticFilter!(hasUDA, overloads);

	alias wrap(alias member) = AliasSeq!(member, getUDAs!(member, uda));

	alias getFunctionsWithUDA = staticMap!(wrap, udaMembers);
}
