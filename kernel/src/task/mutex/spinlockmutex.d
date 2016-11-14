module task.mutex.spinlockmutex;

private extern (C) void mutexSpinlock(ulong* value);
private extern (C) ulong mutexTrylock(ulong* value);
private extern (C) void mutexUnlock(ulong* value);

struct SpinLockMutex {
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
