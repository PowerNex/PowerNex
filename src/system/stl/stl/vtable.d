/**
 * Helper function for managing VTables
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *    (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.vtable;

/**
 * VTablePtr verifies that the $(PARAM TInput) function uses the same prototype
 * as $(PARAM Target), and that the first argument extends the first argument of $(PARAM Target).
 * Params:
 *      Target - The function pointer type to be cast to
 *      TInput - The function pointer type that will be cast
 *      Input  - The function pointer of type TInput
 */
pragma(inline, true) Target VTablePtr(Target, TInput)(TInput Input) {
	import stl.trait : parameters, Unqual;

	alias T = parameters!Target[0];
	alias I = parameters!TInput[0];

	static foreach (name; __traits(allMembers, I)) {
		static if (is(typeof(__traits(getMember, I, name)) == T))
			static assert(__traits(getMember, I, name).offsetof == 0, T.stringof ~ " needs to be the first member in " ~ I.stringof);
	}
	static assert(is(parameters!Target[1 .. $] == parameters!TInput[1 .. $]));
	return cast(Target)Input;
}
