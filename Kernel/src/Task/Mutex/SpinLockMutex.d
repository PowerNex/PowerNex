module Task.Mutex.SpinLockMutex;

import Task.Mutex.Mutex;

private extern (C) void spinlock_lock(ulong* value);
private extern (C) ulong spinlock_trylock(ulong* value);
private extern (C) void spinlock_unlock(ulong* value);

struct SpinLockMutex {
public:
	void Lock() {
		spinlock_lock(&value);
	}

	bool TryLock() {
		return !!spinlock_trylock(&value);
	}

	void Unlock() {
		spinlock_unlock(&value);
	}

private:
	ulong value;
}
