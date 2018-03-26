/**
 * Helper function for managing VTables
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.vtable;

pragma(inline, true) Target VTablePtr(Target, TInput)(TInput Input) {
	import stl.trait : parameters, Unqual;

	pragma(msg, TInput, " => ", Target);

	alias T = parameters!Target[0];
	alias I = parameters!TInput[0];

	static foreach (name; __traits(allMembers, I)) {
		static if (is(typeof(__traits(getMember, I, name)) == T))
			static assert(__traits(getMember, I, name).offsetof == 0, T.stringof ~ " needs to be the first member in " ~ I.stringof);
	}
	static assert(is(parameters!Target[1 .. $] == parameters!TInput[1 .. $]));
	return cast(Target)Input;
}
