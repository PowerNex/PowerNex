module CPU.PIT;

import CPU.IDT;
import IO.Port;
import IO.Log;
import Data.Register;
import Task.Scheduler;

struct PIT {
public:
	static void Init(uint hz = 1000) {
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
		import Memory.FrameAllocator;
		import Task.Scheduler;
		import IO.TextMode : scr = GetScreen;

		counter++;

		const ulong usedMiB = FrameAllocator.UsedFrames / 256;
		const ulong maxMiB = FrameAllocator.MaxFrames / 256;
		const ulong pid = (scheduler) ? scheduler.CurrentThread.Pid : 0;
		ulong memory;
		if (maxMiB)
			memory = (usedMiB * 100) / maxMiB;
		scr.WriteStatus("Memory used: ", usedMiB, "MiB/", maxMiB, "MiB(", memory, "%)\tPID: ", pid, "\tSeconds since boot: ", Seconds);

		if (scheduler)
			scheduler.Schedule();
	}
}
