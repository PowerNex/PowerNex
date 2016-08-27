module Task.Mutex.SpinLockMutex;

private extern (C) void mutex_spinlock(ulong* value);
private extern (C) ulong mutex_trylock(ulong* value);
private extern (C) void mutex_unlock(ulong* value);

struct SpinLockMutex {
public:
	void Lock() {
		mutex_spinlock(&value);
	}

	bool TryLock() {
		return !!mutex_trylock(&value);
	}

	void Unlock() {
		mutex_unlock(&value);
	}

private:
	ulong value;
}
