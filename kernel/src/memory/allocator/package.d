module memory.allocator;

import memory.ref_;

// Based on https://github.com/dlang/phobos/blob/master/std/experimental/allocator/package.d#L259
interface IAllocator {
	void[] allocate(size_t size);
	//void[] alignedAllocate(size_t size, uint alignment);

	bool expand(ref void[] data, size_t deltaSize);

	bool reallocate(ref void[] data, size_t size);
	//bool alignedReallocate(ref void[] data, size_t size, uint alignment);

	bool deallocate(void[] data);
	bool deallocateAll();
}

auto make(T, Allocator, A...)(auto ref Allocator alloc, auto ref A args) {
	static if (is(T == class)) {
		static assert(!__traits(isAbstractClass, T), T.stringof ~ " is abstract and it can't be emplaced");
		enum size = __traits(classInstanceSize, T);
		alias ReturnType = T;
	} else {
		enum size = T.sizeof;
		alias ReturnType = T*;
	}

	void[] chunk = alloc.allocate(size);
	auto result = cast(ReturnType)chunk.ptr;

	memset(chunk.ptr, 0, size);
	auto init = typeid(T).init;

	chunk[0 .. init.length] = init[];

	static if (is(typeof(result.__ctor(args))))
		result.__ctor(args);
	else static if (is(typeof(T(args))))
		*result = T(args);
	else static if (args.length == 1 && !is(typeof(&T.__ctor)) && is(typeof(*result = args[0])))
		*result = args[0];
	else
		static assert(args.length == 0 && !is(typeof(&T.__ctor)),
				"Don't know how to initialize an object of type " ~ T.stringof ~ " with arguments " ~ A.stringof);
	return result;
}

auto makeRef(T, Allocator, A...)(auto ref Allocator alloc, auto ref A args) {
	return Ref!T(alloc.make!T(args), alloc);
}

//TODO: support ranges?
T[] makeArray(T, Allocator)(auto ref Allocator alloc, size_t length) {
	return makeArray!T(alloc, length, T());
}

T[] makeArray(T, Allocator)(auto ref Allocator alloc, size_t length, auto ref T init) {
	T[] arr = cast(T[])alloc.allocate(T.sizeof * length);
	foreach (ref e; arr)
		e = init;
	return arr;
}

bool expandArray(T, Allocator)(auto ref Allocator alloc, ref T[] arr, size_t deltaSize) {
	return expandArray!T(alloc, arr, deltaSize, T());
}

bool expandArray(T, Allocator)(auto ref Allocator alloc, ref T[] arr, size_t deltaSize, auto ref T init) {
	void[] buf = arr;
	if (!alloc.expand(buf, deltaSize * T.sizeof))
		if (!alloc.reallocate(buf, (arr.length + deltaSize) * T.sizeof))
			return false;
	arr = cast(T[])buf;
	foreach (ref e; arr[$ - deltaSize .. $])
		e = init;
	return true;
}

void dispose(T, Allocator)(auto ref Allocator alloc, T* obj) {
	alloc.deallocate((cast(void*)obj)[0 .. T.sizeof]);
}

void dispose(T, Allocator)(auto ref Allocator alloc, T* obj) if (is(T == struct)) {
	static if (is(typeof(obj.__dtor())))
		obj.__dtor();

	alloc.deallocate((cast(void*)obj)[0 .. T.sizeof]);
}

void dispose(T, Allocator)(auto ref Allocator alloc, T obj) if (is(T == interface)) {
	dispose(alloc, cast(Object)obj);
}

void dispose(T, Allocator)(auto ref Allocator alloc, T obj) if (is(T == class)) {
	ClassInfo ci = typeid(obj);
	void* object = cast(void*)_d_dynamic_cast(cast(Object)obj, ci);

	ClassInfo origCI = ci;

	while (ci) {
		if (ci.destructor) {
			auto dtor = cast(void function(void*))ci.destructor;
			dtor(object);
		}
		ci = ci.base;
	}
	alloc.deallocate(object[0 .. origCI.tsize]);
}

void dispose(T, Allocator)(auto ref Allocator alloc, T[] arr) {
	static if (is(typeof(obj[0].__dtor())))
		foreach (ref e; arr)
			arr.__dtor();

	alloc.deallocate(cast(void[])arr);
}

__gshared IAllocator kernelAllocator = null;

void initEarlyStaticAllocator() {
	import memory.allocator.staticallocator;
	import data.util : inplaceClass;

	align(16) __gshared ubyte[0x1000] staticAllocationSpace; // 4KiB should be enought.
	__gshared ubyte[__traits(classInstanceSize, StaticAllocator)] data;
	kernelAllocator = inplaceClass!StaticAllocator(data, staticAllocationSpace);
}
