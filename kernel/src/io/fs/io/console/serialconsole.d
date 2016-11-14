module io.fs.io.console.serialconsole;

import io.fs;
import io.fs.io.console;

import io.com;
import cpu.idt;

class SerialConsole : Console {
public:
	this(ref COM com) {
		_com = &com;
	}

	override bool open() {
		if (_inUse)
			return false;
		return _inUse = true;
	}

	override void close() {
		_inUse = false;
	}

	override ulong read(ubyte[] buffer, ulong offset) {
		size_t read;

		while (read < buffer.length && _com.canRead)
			buffer[read++] = _com.read();

		return read;
	}

	override ulong write(ubyte[] buffer, ulong offset) {
		foreach (ubyte b; buffer)
			_com.write(b);
		return buffer.length;
	}

private:
	bool _inUse;
	COM* _com;
}
