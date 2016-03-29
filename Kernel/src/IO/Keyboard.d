module IO.Keyboard;

struct Keyboard {
public:
	static dchar Pop() {
		dchar ch = Peek();
		if (ch)
			start++;
		return ch;
	}

	static dchar Peek() {
		if (start != end)
			return buffer[start];
		else
			return '\0';
	}

	static void Push(dchar ch) {
		buffer[end++] = ch;
	}

private:
	__gshared dchar[256] buffer;
	__gshared ubyte start, end;
}
