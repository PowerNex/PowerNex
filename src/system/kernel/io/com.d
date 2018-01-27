module io.com;

import io.port;
import arch.amd64.idt;
import stl.register;

ref COM com1() {
	return comPorts[0];
}

ref COM com2() {
	return comPorts[1];
}

ref COM com3() {
	return comPorts[2];
}

ref COM com4() {
	return comPorts[3];
}

__gshared COM[] comPorts = [COM(0x3F8), COM(0x2F8), COM(0x3E8), COM(0x2E8)];

enum Mode {
	eightByteNoParityOneStopBit = 0x03,
	divisorLatch = 0x80,
}

enum PortNumber : ushort {
	transmit = 0, // w
	recieve = 0, // r
	divisorLow = 0, // rw latch
	interruptEnable = 1, // rw
	divisorHigh = 1, // rw latch
	interruptIdentifier = 2, // r
	fifoControl = 2, // w
	lineControl = 3, // rw
	modemControl = 4, // rw
	lineStatus = 5, // r
	modemStatus = 6, // r
	scratch = 7, // rw
}

enum InterruptSettings : ubyte {
	enableTransmit = 1 << 1,
	enableRecieve = 1 << 0,
}

enum StatusInfo : ubyte {
	interrupt = 1 << 0,
	reason = 0b1110,

	reasonStatus = 0b0110,
	reasonReceiver = 0b0100,
	reasonFifo = 0b1100,
	reasonTransmission = 0b0010,
	reasonModem = 0b0000,
}

struct COM {
	ushort port;
	char[0x1000] buf;
	ushort start, end;

	static void init() {
		enum divisor = 115200;
		ushort speed = divisor / 9600;

		IDT.register(irq(4), &_handleIRQ4);
		IDT.register(irq(3), &_handleIRQ3);

		foreach (com; comPorts) {
			outp!ubyte(cast(ushort)(com.port + PortNumber.interruptEnable), 0);

			outp!ubyte(cast(ushort)(com.port + PortNumber.lineControl), Mode.divisorLatch | Mode.eightByteNoParityOneStopBit);
			outp!ubyte(cast(ushort)(com.port + PortNumber.divisorHigh), cast(ubyte)(speed >> 8));
			outp!ubyte(cast(ushort)(com.port + PortNumber.divisorLow), cast(ubyte)speed);

			outp!ubyte(cast(ushort)(com.port + PortNumber.lineControl), Mode.eightByteNoParityOneStopBit);

			outp!ubyte(cast(ushort)(com.port + PortNumber.fifoControl), 0xC7); // Enable FIFO, clear them, with 14-byte threshold

			outp!ubyte(cast(ushort)(com.port + PortNumber.interruptEnable), InterruptSettings.enableRecieve);
		}
	}

	bool canRead() {
		return (start != end);
	}

	ubyte read() {
		while (!canRead()) { //XXX:
		}
		return buf[(++start % 0x1000)];
	}

	bool canSend() {
		return !!(inp!ubyte(cast(ushort)(port + 5)) & 0x20);
	}

	void write(ubyte d) {
		while (!canSend()) { //XXX: fix deadlock
		}
		outp!ubyte(cast(ushort)port, d);
	}

	void write(T : ubyte)(T[] data) {
		foreach (d; data)
			write(d);
	}

	void write(Args...)(Args args) {
		foreach (arg; args)
			write(arg);
	}

private:
	static void _handleIRQ3(Registers*) {
		_handleIRQ!com2();
		_handleIRQ!com4();
	}

	static void _handleIRQ4(Registers*) {
		_handleIRQ!com1();
		_handleIRQ!com3();
	}

	static void _handleIRQ(alias com)() {
		import data.textbuffer : scr = getBootTTY;
		import stl.text : BinaryInt;

		StatusInfo status = cast(StatusInfo)inp!ubyte(cast(ushort)(com.port + PortNumber.interruptIdentifier));
		while (!(status & StatusInfo.interrupt)) {
			status &= StatusInfo.reason;
			switch (status) with (StatusInfo) {
			case reasonStatus:
				ubyte line = inp!ubyte(cast(ushort)(com.port + PortNumber.lineStatus));
				//TODO: Check line status?
				break;
			case reasonReceiver:
			case reasonFifo: //TODO: Check if ReasonFIFO should be it's own case
				while (inp!ubyte(cast(ushort)(com.port + PortNumber.lineStatus)) & 0x1) {
					ubyte tmp = inp!ubyte(com.port);
					//scr.Writeln("Char: ", tmp);
					if ((com.end + 1 % 0x1000) != com.start)
						com.buf[(++com.end % 0x1000)] = tmp;
				}
				break;
			case reasonTransmission:
				//TODO: transmit stuff here
				break;
			case reasonModem:
				ubyte modem = inp!ubyte(cast(ushort)(com.port + PortNumber.modemStatus));
				//TODO: Check modem status?
				break;
			default: // Will never happen!
				assert(0);
				break;
			}
			status = cast(StatusInfo)inp!ubyte(cast(ushort)(com.port + PortNumber.interruptIdentifier));
		}
	}
}
