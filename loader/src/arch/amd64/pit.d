module arch.amd64.pit;

@safe static struct PIT {
public static:
	void init(uint hz = 1000) @trusted {
		import arch.amd64.idt : IDT, irq;
		import io.ioport : outp;

		IDT.register(irq(0), &_onTick);
		_hz = hz;
		uint divisor = 1193180 / hz;
		outp!ubyte(0x43, 0x36);

		ubyte l = cast(ubyte)(divisor & 0xFF);
		ubyte h = cast(ubyte)((divisor >> 8) & 0xFF);

		outp!ubyte(0x40, l);
		outp!ubyte(0x40, h);
	}

	@property ulong seconds() @trusted {
		if (_hz)
			return _counter / _hz;
		return 0;
	}

	void clear() @trusted {
		_counter = 0;
	}

	void sleep(size_t amount) @trusted {
		size_t endAt = _counter + amount;

		while (_counter < endAt) {
			asm pure nothrow {
				hlt;
			}
		}
	}

private static:
	__gshared bool _enabled;
	__gshared uint _hz;
	__gshared size_t _counter;

	void _onTick(from!"arch.amd64.register".Registers* regs) @trusted {
		_counter++;
	}
}
