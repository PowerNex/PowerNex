module stl.arch.amd64.cpu;

size_t getCoreID() @safe {
	import stl.arch.amd64.lapic : LAPIC;
	return LAPIC.getCurrentID();
}
