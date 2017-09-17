module arch.amd64.smp;

import data.address;

extern (C) extern __gshared ubyte boot16_location, boot16_start, boot16_end;

@safe static struct SMP {
public static:
	void init() @trusted {
		import arch.amd64.lapic : LAPIC;
		import api : APIInfo;
		import api.cpu : CPUThread;
		import io.log : Log;

		_setupInit16();

		foreach (size_t idx, ref CPUThread cpuThread; APIInfo.cpus.cpuThreads) {
			if (cpuThread.state != CPUThread.State.off) {
				Log.debug_("Skipping cpuThreads[", idx, "] it's state is: ", cpuThread.state);
				continue;
			}

			Log.debug_("cpuThreads[", idx, "].init()");
			LAPIC.init(cpuThread.apicID, true);
			LAPIC.sleep(2);
			LAPIC.init(cpuThread.apicID, false);
			LAPIC.sleep(10);

			Log.debug_("cpuThreads[", idx, "].startup()");
			LAPIC.startup(cpuThread.apicID, PhysAddress32(&boot16_location));
			LAPIC.sleep(2); // ~1ms I guess
			LAPIC.startup(cpuThread.apicID, PhysAddress32(&boot16_location));
			LAPIC.sleep(2); // ~1ms I guess

			while (cpuThread.state == CPUThread.State.off) {
				LAPIC.sleep(1);
			}
		}
	}

private static:
	void _setupInit16() @trusted {
		VirtAddress(&boot16_location).memcpy(VirtAddress(&boot16_start), cast(size_t)&boot16_end - cast(size_t)&boot16_start);
	}
}
