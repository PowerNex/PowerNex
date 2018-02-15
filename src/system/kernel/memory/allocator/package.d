module memory.allocator;

import memory.ptr;
import stl.address;

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
	static if (is(T == class) || is(T == interface)) {
		static assert(!is(T == interface) && !__traits(isAbstractClass, T), T.stringof ~ " is abstract and it can't be emplaced");
		enum size = __traits(classInstanceSize, T);
		alias ReturnType = T;
	} else {
		enum size = T.sizeof;
		alias ReturnType = T*;
	}

	void[] chunk = alloc.allocate(size);
	if (!chunk) {
		import io.log : Log;

		Log.fatal("Failed to allocate size: ", size);
	}
	auto result = cast(ReturnType)chunk.ptr;

	memset(chunk.ptr, 0, size);
	auto init = typeid(T).initializer;
	if (init.ptr)
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

auto makeSharedPtr(T, X = T, Allocator, A...)(auto ref Allocator allocator, auto ref A args) {
	return SharedPtr!(T)(allocator, args);
}

//TODO: support ranges?
T[] makeArray(T, Allocator)(auto ref Allocator alloc, size_t length) {
	return makeArray!T(alloc, length, T.init);
}

T[] makeArray(T, Allocator)(auto ref Allocator alloc, size_t length, auto ref T init) {
	T[] arr = cast(T[])alloc.allocate(T.sizeof * length);
	foreach (ref e; arr)
		e = init;
	return arr;
}

T[] dupArray(T, Allocator)(auto ref Allocator alloc, in T[] otherArray) {
	if (!otherArray)
		return null;
	T[] arr = makeArray!T(alloc, otherArray.length);
	if (!arr)
		return null;
	arr[] = otherArray[];
	return arr;
}

bool expandArray(T, Allocator)(auto ref Allocator alloc, ref T[] arr, size_t deltaSize) {
	void[] buf = arr;
	if (!alloc.expand(buf, deltaSize * T.sizeof))
		if (!alloc.reallocate(buf, (arr.length + deltaSize) * T.sizeof))
			return false;

	void[] newData = buf[$ - (deltaSize * T.sizeof) .. $];

	memset(newData.ptr, 0, newData.length);
	//memset((VirtAddress(buf) + (arr.length - deltaSize) * T.sizeof).ptr, 0, deltaSize * T.sizeof);

	arr = cast(T[])buf;

	auto init = typeid(T).initializer;
	if (init.ptr)
		for (size_t i = 0; i < deltaSize; i++) {
			size_t loc = i * T.sizeof;
			newData[loc .. loc + init.length] = init[];
		}

	return true;
}

void dispose(T, Allocator)(auto ref Allocator alloc, T* obj) if (!is(T == struct)) {
	if (!obj)
		return;
	alloc.deallocate((cast(void*)obj)[0 .. T.sizeof]);
}

void dispose(T, Allocator)(auto ref Allocator alloc, T* obj) if (is(T == struct)) {
	if (!obj)
		return;
	typeid(T).destroy(obj);

	alloc.deallocate((cast(void*)obj)[0 .. T.sizeof]);
}

void dispose(T, Allocator)(auto ref Allocator alloc, T obj) if (is(T == interface)) {
	if (!obj)
		return;
	dispose(alloc, cast(Object)obj);
}

void dispose(T, Allocator)(auto ref Allocator alloc, T obj) if (is(T == class)) {
	if (!obj)
		return;
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
	if (!arr)
		return;

	foreach (ref obj; arr)
		static if (is(T == struct))
			typeid(T).destroy(cast(void*)&obj);
		else static if (is(T == class)) {
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
		} else static if (is(T == E*, E))
			alloc.deallocate(alloc, obj);

	alloc.deallocate(cast(void[])arr);
}

__gshared IAllocator kernelAllocator = null;

void initKernelAllocator() {
	import memory.allocator.kheapallocator;
	import stl.trait : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, KHeapAllocator)] data;
	kernelAllocator = inplaceClass!KHeapAllocator(data);
}
