module IO.COM;

import IO.Port;
import CPU.IDT;
import Data.Register;

ref COM COM1() {
	return COMPorts[0];
}

ref COM COM2() {
	return COMPorts[1];
}

ref COM COM3() {
	return COMPorts[2];
}

ref COM COM4() {
	return COMPorts[3];
}

__gshared COM[] COMPorts = [COM(0x3F8), COM(0x2F8), COM(0x3E8), COM(0x2E8)];

enum Mode {
	EightByteNoParityOneStopBit = 0x03,
	DivisorLatch = 0x80,
}

enum PortNumber : ushort {
	Transmit = 0, // w
	Recieve = 0, // r
	DivisorLow = 0, // rw latch
	InterruptEnable = 1, // rw
	DivisorHigh = 1, // rw latch
	InterruptIdentifier = 2, // r
	FIFOControl = 2, // w
	LineControl = 3, // rw
	ModemControl = 4, // rw
	LineStatus = 5, // r
	ModemStatus = 6, // r
	Scratch = 7, // rw
}

enum InterruptSettings : ubyte {
	EnableTransmit = 1 << 1,
	EnableRecieve = 1 << 0,
}

enum StatusInfo : ubyte {
	Interrupt = 1 << 0,
	Reason = 0b1110,

	ReasonStatus = 0b0110,
	ReasonReceiver = 0b0100,
	ReasonFIFO = 0b1100,
	ReasonTransmission = 0b0010,
	ReasonModem = 0b0000,
}

struct COM {
	ushort port;
	char[0x1000] buf;
	ushort start, end;

	static void Init() {
		enum Divisor = 115200;
		ushort speed = Divisor / 9600;

		IDT.Register(IRQ(4), &handleIRQ4);
		IDT.Register(IRQ(3), &handleIRQ3);

		foreach (com; COMPorts) {
			Out!ubyte(cast(ushort)(com.port + PortNumber.InterruptEnable), 0);

			Out!ubyte(cast(ushort)(com.port + PortNumber.LineControl), Mode.DivisorLatch | Mode.EightByteNoParityOneStopBit);
			Out!ubyte(cast(ushort)(com.port + PortNumber.DivisorHigh), cast(ubyte)(speed >> 8));
			Out!ubyte(cast(ushort)(com.port + PortNumber.DivisorLow), cast(ubyte)speed);

			Out!ubyte(cast(ushort)(com.port + PortNumber.LineControl), Mode.EightByteNoParityOneStopBit);

			Out!ubyte(cast(ushort)(com.port + PortNumber.FIFOControl), 0xC7); // Enable FIFO, clear them, with 14-byte threshold

			Out!ubyte(cast(ushort)(com.port + PortNumber.InterruptEnable), InterruptSettings.EnableRecieve);
		}
	}

	bool CanRead() {
		return (start != end);
	}

	ubyte Read() {
		while (!CanRead()) { //XXX:
		}
		return buf[(++start % 0x1000)];
	}

	bool CanSend() {
		return !!(In(cast(ushort)(port + 5)) & 0x20);
	}

	void Write(ubyte d) {
		while (!CanSend()) { //XXX: fix deadlock
		}
		Out!ubyte(cast(ushort)port, d);
	}

	void Write(T : ubyte)(T[] data) {
		foreach (d; data)
			Write(d);
	}

	void Write(Args...)(Args args) {
		foreach (arg; args)
			Write(arg);
	}

	static void handleIRQ3(Registers*) {
		handleIRQ!COM2();
		handleIRQ!COM4();
	}

	static void handleIRQ4(Registers*) {
		handleIRQ!COM1();
		handleIRQ!COM3();
	}

	static void handleIRQ(alias com)() {
		import Data.TextBuffer : scr = GetBootTTY;
		import Data.Util : BinaryInt;

		StatusInfo status = cast(StatusInfo)In!ubyte(cast(ushort)(com.port + PortNumber.InterruptIdentifier));
		while (!(status & StatusInfo.Interrupt)) {
			status &= StatusInfo.Reason;
			switch (status) with (StatusInfo) {
			case ReasonStatus:
				ubyte line = In(cast(ushort)(com.port + PortNumber.LineStatus));
				//TODO: Check line status?
				break;
			case ReasonReceiver:
			case ReasonFIFO: //TODO: Check if ReasonFIFO should be it's own case
				while (In(cast(ushort)(com.port + PortNumber.LineStatus)) & 0x1) {
					ubyte tmp = In(com.port);
					//scr.Writeln("Char: ", tmp);
					if ((com.end + 1 % 0x1000) != com.start)
						com.buf[(++com.end % 0x1000)] = tmp;
				}
				break;
			case ReasonTransmission:
				//TODO: Transmit stuff here
				break;
			case ReasonModem:
				ubyte modem = In(cast(ushort)(com.port + PortNumber.ModemStatus));
				//TODO: Check modem status?
				break;
			default: // Will never happen!
				assert(0);
				break;
			}
			status = cast(StatusInfo)In!ubyte(cast(ushort)(com.port + PortNumber.InterruptIdentifier));
		}
	}
}
