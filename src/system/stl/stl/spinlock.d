/**
 * A spinlock implementation.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
module stl.spinlock;

private extern (C) void mutexSpinlock(ulong* value) @trusted;
private extern (C) ulong mutexTrylock(ulong* value) @trusted;
private extern (C) void mutexUnlock(ulong* value) @trusted;

///
@safe struct SpinLock {
public:
	///
	void lock() {
		mutexSpinlock(&_value);
	}

	///
	bool tryLock() {
		return !!mutexTrylock(&_value);
	}

	///
	void unlock() {
		mutexUnlock(&_value);
	}

private:
	ulong _value;
}
