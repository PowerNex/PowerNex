/**
 * Range helper functions and algorithmic functions.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.range;

interface InputRange(E) {
	@property ref const(E) front() const;
	@property ref E front();
	E moveFront();
	void popFront();
	@property bool empty() const;
	int opApply(scope int delegate(const E) cb);
	int opApply(scope int delegate(ref E) cb);
	int opApply(scope int delegate(size_t, const E) cb);
	int opApply(scope int delegate(size_t, ref E) cb);
}

interface ForwardRange(E) : InputRange!E {
	@property ForwardRange!E save();
}

interface BidirectionalRange(E) : ForwardRange!E {
	@property BidirectionalRange!E save();
	@property E back();
	E moveBack();
	void popBack();
}

interface RandomAccessFinite(E) : BidirectionalRange!E {
	@property RandomAccessFinite!E save();
	ref const(E) opIndex(size_t index) const;
	ref E opIndex(size_t index);
	E moveAt(size_t index);
	@property size_t length();
	alias opDollar = length;
	RandomAccessFinite!E opSlice(size_t start, size_t end);
}

interface InputAssignable(E) : InputRange!E {
	@property void front(E newValue);
}

interface ForwardAssignable(E) : InputAssignable!E, ForwardRange!E {
	@property ForwardAssignable!E save();
}

interface BidirectionalAssignable(E) : ForwardAssignable!E, BidirectionalRange!E {
	@property BidirectionalAssignable!E save();
	@property void back(E newValue);
}

interface RandomFiniteAssignable(E) : BidirectionalAssignable!E, RandomAccessFinite!E {
	@property RandomFiniteAssignable!E save();
	void opIndexAssign(E val, size_t index);
}

interface OutputRange(E) {
	ref E put(E value);
}

///
struct MapRange(alias Function, Range) {
	Range r; ///

	///
	void popFront() {
		r.popFront();
	}

	///
	@property auto front() {
		return Function(r.front);
	}

	///
	@property bool empty() {
		return r.empty;
	}
}

///
auto map(alias Function, Range)(Range r) {
	return MapRange!(Function, Range)(r);
}

///
ref T[] popFront(T)(return ref T[] array) {
	assert(array.length, "Array is empty");
	array = array[1 .. $];
	return array;
}

///
T front(T)(T[] array) {
	assert(array.length, "Array is empty");
	return array[0];
}

///
bool empty(T)(T[] array) {
	return !array.length;
}
