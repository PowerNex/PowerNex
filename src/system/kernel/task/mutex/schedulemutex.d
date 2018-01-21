module task.mutex.schedulemutex;

import task.process;
import task.scheduler;

private extern (C) ulong mutexTrylock(ulong* value);
private extern (C) void mutexUnlock(ulong* value);

struct ScheduleMutex {
public:
	void lock() {
		while (!mutexTrylock(&_value))
			{}//getScheduler.waitFor(WaitReason.mutex, cast(ulong)&this);
	}

	bool tryLock() {
		return !!mutexTrylock(&_value);
	}

	void unlock() {
		mutexUnlock(&_value);
		//getScheduler.wakeUp(WaitReason.mutex, cast(WakeUpFunc)&_mutexWakeUp, &this);
	}

private:
	ulong _value;

	static bool _mutexWakeUp(Process* p, ScheduleMutex* self) {
		if (p.waitData == cast(ulong)self)
			return true;
		return false;
	}
}
