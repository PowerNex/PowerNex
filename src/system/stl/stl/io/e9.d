module stl.io.e9;

/// The E9 debug output port
@safe struct E9 {
public static:
	///
	void write(ubyte d) {
		import stl.arch.amd64.ioport : outp;

		outp!ubyte(0xE9, d);
	}

	///
	void write(T : ubyte)(T[] data) {
		foreach (d; data)
			write(d);
	}

	///
	void write(Args...)(Args args) {
		foreach (arg; args)
			write(arg);
	}
}
