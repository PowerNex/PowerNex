module Task.Mutex.ScheduleMutex;

import Task.Process;
import Task.Scheduler;

private extern (C) ulong mutex_trylock(ulong* value);
private extern (C) void mutex_unlock(ulong* value);

struct ScheduleMutex {
public:
	void Lock() {
		while(!mutex_trylock(&value))
			GetScheduler.WaitFor(WaitReason.Mutex, cast(ulong)&this);
	}

	bool TryLock() {
		return !!mutex_trylock(&value);
	}

	void Unlock() {
		mutex_unlock(&value);
		GetScheduler.WakeUp(WaitReason.Mutex, cast(WakeUpFunc)&mutexWakeUp, &this);
	}

private:
	static bool mutexWakeUp(Process* p, ScheduleMutex* self) {
		if(p.waitData == cast(ulong)self)
			return true;
		return false;
	}

	ulong value;
}
