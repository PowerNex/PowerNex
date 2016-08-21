module IO.Keyboard;

import Task.Process;
import Task.Scheduler;

struct Keyboard {
public:
	static wchar Pop() {
		wchar ch = Peek();
		while (!ch) {
			GetScheduler.WaitFor(WaitReason.Keyboard);
			ch = Peek();
		}

		start++;
		return ch;
	}

	static wchar Peek() {
		if (start != end)
			return buffer[start];
		else
			return '\0';
	}

	static void Push(wchar ch) {
		buffer[end++] = ch;
		GetScheduler.WakeUp(WaitReason.Keyboard);
	}

private:
	__gshared wchar[256] buffer;
	__gshared ubyte start, end;
}
