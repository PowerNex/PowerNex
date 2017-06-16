module util.spinlock;

private extern (C) void mutexSpinlock(ulong* value) @trusted;
private extern (C) ulong mutexTrylock(ulong* value) @trusted;
private extern (C) void mutexUnlock(ulong* value) @trusted;

@safe struct SpinLock {
public:
	void lock() {
		mutexSpinlock(&_value);
	}

	bool tryLock() {
		return !!mutexTrylock(&_value);
	}

	void unlock() {
		mutexUnlock(&_value);
	}

private:
	ulong _value;
}
