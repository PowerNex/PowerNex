module IO.Keyboard;

struct Keyboard {
public:
	static wchar Pop() {
		wchar ch = Peek();
		if (ch)
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
	}

private:
	__gshared wchar[256] buffer;
	__gshared ubyte start, end;
}
