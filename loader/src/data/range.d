module data.range;

struct MapRange(alias Function, Range) {
	Range r;

	void popFront() {
		r.popFront();
	}

	@property auto front() {
		return Function(r.front);
	}

	@property bool empty() {
		return r.empty;
	}
}

auto map(alias Function, Range)(Range r) {
	return MapRange!(Function, Range)(r);
}

ref T[] popFront(T)(return ref T[] array) {
	assert(array.length, "Array is empty");
	array = array[1 .. $];
	return array;
}

T front(T)(T[] array) {
	assert(array.length, "Array is empty");
	return array[0];
}

bool empty(T)(T[] array) {
	return !array.length;
}
