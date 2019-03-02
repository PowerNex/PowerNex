module arch.amd64.smp;

import stl.address;

extern (C) extern __gshared ubyte boot16_location, boot16_start, boot16_end, boot16_start_halt, boot16_end_halt;

@safe static struct SMP {
public static:
	void init() @trusted {
		import stl.arch.amd64.lapic : LAPIC;
		import stl.arch.amd64.tsc : TSC;
		import powerd.api : getPowerDAPI;
		import powerd.api.cpu : CPUThread;
		import stl.io.log : Log;

		_setupInit16();

		foreach (size_t idx, ref CPUThread cpuThread; getPowerDAPI.cpus.cpuThreads) {
			if (cpuThread.state != CPUThread.State.off) {
				Log.debug_("Skipping cpuThreads[", idx, "] it's state is: ", cpuThread.state);
				continue;
			}

			debug {
				auto code = VirtMemoryRange(_start, _end).array!ubyte;
				auto correctCode = VirtMemoryRange(_location, _location + (_end - _start)).array!ubyte;

				if (code != correctCode) {
					size_t wrongOffset;
					for (size_t i; i < code.length; i++)
						if (code[i] != correctCode[i]) {
							wrongOffset = i;
							break;
						}
					Log.fatal("BOOT CODE IS INVALID!\nCorrect Code: ", correctCode, "\n    RAM Code: ", code, "\nWrong offset: ",
							wrongOffset, "(", cast(void*)code[wrongOffset], " != ", cast(void*)correctCode[wrongOffset]);
				}
			}

			Log.debug_("cpuThreads[", idx, "].init(): ", cpuThread.apicID);
			LAPIC.init(cpuThread.apicID, true);
			TSC.sleep(10);
			LAPIC.init(cpuThread.apicID, false);
			TSC.sleep(10);

			Log.debug_("cpuThreads[", idx, "].startup()1: ", cpuThread.apicID, " location: ", PhysAddress32(&boot16_location));
			LAPIC.startup(cpuThread.apicID, PhysAddress32(&boot16_location));
			TSC.sleep(10); // ~1ms I guess
			LAPIC.startup(cpuThread.apicID, PhysAddress32(&boot16_location));
			TSC.sleep(10); // ~1ms I guess

			size_t counter = 0;
			while (cpuThread.state == CPUThread.State.off && counter < 1000) {
				TSC.sleep(10);
				counter++;
			}
			if (counter >= 1000)
				Log.error("cpuThreads[", idx, "] failed to boot! counter: ", counter);
		}

		_setupHaltInit16();
	}

private static:
	void _setupInit16() @trusted {
		import stl.io.log : Log;

		Log.info("memcpy(", _location, ", ", _start, ", ", _end - _start, ");");
		_location.memcpy(_start, (_end - _start).num);
	}

	void _setupHaltInit16() @trusted {
		import stl.io.log : Log;

		Log.info("memcpy(", _location, ", ", _startHalt, ", ", _endHalt - _startHalt, ");");
		_location.memcpy(_startHalt, (_endHalt - _startHalt).num);
	}

	@property VirtAddress _location() @trusted {
		return VirtAddress(&boot16_location);
	}

	@property VirtAddress _start() @trusted {
		return VirtAddress(&boot16_start);
	}

	@property VirtAddress _end() @trusted {
		return VirtAddress(&boot16_end);
	}

	@property VirtAddress _startHalt() @trusted {
		return VirtAddress(&boot16_start_halt);
	}

	@property VirtAddress _endHalt() @trusted {
		return VirtAddress(&boot16_end_halt);
	}
}
