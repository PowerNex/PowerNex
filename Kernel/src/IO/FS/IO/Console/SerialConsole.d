module IO.FS.IO.Console.SerialConsole;

import IO.FS;
import IO.FS.IO.Console;

import IO.COM;
import CPU.IDT;

class SerialConsole : Console {
public:
	this(ref COM com) {
		this.com = &com;
	}

	override bool Open() {
		if (inUse)
			return false;
		return inUse = true;
	}

	override void Close() {
		inUse = false;
	}

	override ulong Read(ubyte[] buffer, ulong offset) {
		size_t read;

		while (read < buffer.length && com.CanRead)
			buffer[read++] = com.Read();

		return read;
	}

	override ulong Write(ubyte[] buffer, ulong offset) {
		foreach (ubyte b; buffer)
			com.Write(b);
		return buffer.length;
	}

private:
	bool inUse;
	COM* com;
}
