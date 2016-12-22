module data.range;

interface InputRange(E) {
	@property E front();
	E moveFront();
	void popFront();
	@property bool empty();
	int opApply(scope int delegate(const E) cb) const;
	int opApply(scope int delegate(ref E) cb);
	int opApply(scope int delegate(size_t, const E) cb) const;
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
	E opIndex(size_t index);
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
	void put(E value);
}
