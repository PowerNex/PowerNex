module Task.Mutex.SpinLockMutex;

import Task.Mutex.Mutex;

private extern (C) void spinlock_lock(ulong* value);
private extern (C) ulong spinlock_trylock(ulong* value);
private extern (C) void spinlock_unlock(ulong* value);

class SpinLockMutex : Mutex {
public:
	override void Lock() {
		spinlock_lock(&value);
	}

	override bool TryLock() {
		return !!spinlock_trylock(&value);
	}

	override void Unlock() {
		spinlock_unlock(&value);
	}

private:
	ulong value;
}
