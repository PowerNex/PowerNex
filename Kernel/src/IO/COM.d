module IO.COM;

import IO.Port;
import CPU.IDT;
import Data.Register;

__gshared COM COM1 = COM(0x3F8);
__gshared COM COM2 = COM(0x2F8);
__gshared COM COM3 = COM(0x3E8);
__gshared COM COM4 = COM(0x2E8);

struct COM {
	ushort port;
	bool isInitialized;

	this(ushort port) {
		this.port = port;
		this.isInitialized = false;
	}

	void Init() {
		if (isInitialized)
			return;
		Out(cast(ushort)(port + 1), 0x00); // Disable all interrupts
		Out(cast(ushort)(port + 3), 0x80); // Enable DLAB (set baud rate divisor)
		Out(cast(ushort)(port + 0), 0x03); // Set divisor to 3 (lo byte) 38400 baud
		Out(cast(ushort)(port + 1), 0x00); //                  (hi byte)
		Out(cast(ushort)(port + 3), 0x03); // 8 bits, no parity, one stop bit
		Out(cast(ushort)(port + 2), 0xC7); // Enable FIFO, clear them, with 14-byte threshold
		Out(cast(ushort)(port + 4), 0x0B); // IRQs enabled, RTS/DSR set

		if (port == 0x3F8 || port == 0x3E8)
			IDT.Register(IRQ(4), &IRQIgnore);
		if (port == 0x2F8 || port == 0x2E8)
			IDT.Register(IRQ(3), &IRQIgnore);

		isInitialized = true;
	}

	bool CanRead() {
		return !!(In(cast(ushort)(port + 5)) & 1);
	}

	ubyte Read() {
		while (!CanRead()) {
		}
		return In(port);
	}

	bool CanSend() {
		return !!(In(cast(ushort)(port + 5)) & 0x20);
	}

	void Write(ubyte d) {
		while (!CanSend()) {
		}
		Out(cast(ushort)port, d);
	}

	void Write(T : ubyte)(T[] data) {
		foreach (d; data)
			Write(d);
	}

	void Write(Args...)(Args args) {
		foreach (arg; args)
			Write(arg);
	}

	static void IRQIgnore(Registers*) {
	}
}
