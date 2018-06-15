/**
 * A spinlock implementation.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.spinlock;

private extern extern (C) void mutexSpinlock(uint* value) nothrow @nogc @trusted;
private extern extern (C) ulong mutexTrylock(uint* value) nothrow @nogc @trusted;
private extern extern (C) void mutexUnlock(uint* value) nothrow @nogc @trusted;

///
@safe align(8) struct SpinLock {
public:
	///
	void lock() {
		import stl.io.vga : VGA;

		mutexSpinlock(&_value);
		assert(_value);
	}

	///
	bool tryLock() {
		return !!mutexTrylock(&_value);
	}

	///
	void unlock() {
		assert(_value);
		mutexUnlock(&_value);
	}

	///
	@property bool isLocked() {
		return !!_value;
	}

private:
	align(8) uint _value;
}
