module arch.amd64.pit;

struct PIT {
public:
	static void init(uint hz = 1000) {
		import arch.amd64.idt : IDT, irq;
		import io.port : outp;

		IDT.register(irq(0), &_onTick);
		_hz = hz;
		uint divisor = 1193180 / hz;
		outp!ubyte(0x43, 0x36);

		ubyte l = cast(ubyte)(divisor & 0xFF);
		ubyte h = cast(ubyte)((divisor >> 8) & 0xFF);

		outp!ubyte(0x40, l);
		outp!ubyte(0x40, h);
	}

	static @property ulong seconds() {
		if (_hz)
			return _counter / _hz;
		return 0;
	}

	static void clear() {
		_counter = 0;
	}

private:
	__gshared bool _enabled;
	__gshared uint _hz;
	__gshared ulong _counter;
	static void _onTick(from!"stl.register".Registers* regs) {
		_counter++;
	}
}
