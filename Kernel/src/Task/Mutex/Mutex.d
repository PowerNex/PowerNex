module Task.Mutex.Mutex;

interface Mutex {
	void Lock();
	bool TryLock();
	void Unlock();
}
