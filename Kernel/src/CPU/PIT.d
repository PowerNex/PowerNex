module CPU.PIT;

import CPU.IDT;
import IO.Port;
import IO.Log;
import Data.Register;

struct PIT {
public:
	static void Init(uint hz = 100) {
		IDT.Register(IRQ(0), &onTick);
		this.hz = hz;
		uint divisor = 1193180 / hz;
		Out!ubyte(0x43, 0x36);

		ubyte l = cast(ubyte)(divisor & 0xFF);
		ubyte h = cast(ubyte)((divisor >> 8) & 0xFF);

		Out!ubyte(0x40, l);
		Out!ubyte(0x40, h);
	}

	static @property ulong Seconds() {
		if (hz)
			return counter / hz;
		return 0;
	}

private:
	__gshared bool enabled;
	__gshared uint hz;
	__gshared ulong counter;
	static void onTick(Registers* regs) {
		counter++;
	}
}
