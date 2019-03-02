/**
 *
 *
 * Copyright: © 2019, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.arch.amd64.tsc;

@safe static struct TSC {
public static:
	void sleep(uint msec) @trusted {
		size_t oldTime = void;
		asm {
			rdtsc;
			mov oldTime, RAX;
		}
		while (true) {
			size_t newTime = void;
			asm {
				rdtsc;
				mov newTime, RAX;
			}
			if (oldTime + (msec * frequency) / 1000 < newTime)
				break;
		}
	}

	@property ref size_t frequency() @trusted {
		return _frequency;
	}

private static:
	__gshared size_t _frequency;

}
