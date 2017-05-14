module hw.cmos.cmos;

import io.port;
import cpu.pit;

private enum {
	cmosAddress = 0x70,
	cmosData = 0x71,

	cmosSecond = 0,
	cmosMinute = 2,
	cmosHour = 4,
	cmosDay = 7,
	cmosMonth = 8,
	cmosYear = 9,

	cmosRega = 0x0A,
	cmosRegb = 0x0B
}

class CMOS {
public:
	this(ubyte centuryReg) {
		_centuryReg = centuryReg;
		retrieveTime();
	}

	void retrieveTime() {
		ushort[128] last;
		ushort[128] rawData;
		dump(rawData);

		do {
			foreach (idx, val; rawData)
				last[idx] = val;
			dump(rawData);
		}
		while (last[cmosSecond] != rawData[cmosSecond] || last[cmosMinute] != rawData[cmosMinute]
				|| last[cmosHour] != rawData[cmosHour] || last[cmosDay] != rawData[cmosDay]
				|| last[cmosMonth] != rawData[cmosMonth] || last[cmosYear] != rawData[cmosYear]
				|| last[cmosYear] != rawData[cmosYear] || (_centuryReg && last[_centuryReg] != rawData[_centuryReg]));

		PIT.clear();

		if (!(rawData[cmosRegb] & 0x04)) { // If rawData is BCD
			rawData[cmosSecond] = fromBCD(rawData[cmosSecond]);
			rawData[cmosMinute] = fromBCD(rawData[cmosMinute]);
			rawData[cmosHour] = ((rawData[cmosHour] & 0x0F) + (((rawData[cmosHour] & 0x70) / 16) * 10)) | (rawData[cmosHour] & 0x80);
			rawData[cmosDay] = fromBCD(rawData[cmosDay]);
			rawData[cmosMonth] = fromBCD(rawData[cmosMonth]);
			rawData[cmosYear] = fromBCD(rawData[cmosYear]);
			if (_centuryReg)
				rawData[_centuryReg] = fromBCD(rawData[_centuryReg]);
		}

		if (!(rawData[cmosRegb] & 0x02) && (rawData[cmosHour] & 0x80)) // am/pm -> 24 hours
			rawData[cmosHour] = ((rawData[cmosHour] & 0x7F) + 12) % 24;

		if (_centuryReg)
			rawData[cmosYear] += rawData[_centuryReg] * 100;
		else {
			import data.string_;

			string year = __DATE__[$ - 4 .. $];
			ushort currentYear = cast(ushort)atoi(year);

			rawData[cmosYear] += (currentYear / 100) * 100;
			if (rawData[cmosYear] < currentYear)
				rawData[cmosYear] += 100;
		}

		_timestamp = secondsOfYear(cast(ushort)(rawData[cmosYear] - 1)) + secondsOfMonth(rawData[cmosMonth] - 1,
				rawData[cmosYear]) + (rawData[cmosDay] - 1) * 86400 + (rawData[cmosHour]) * 3600 + (
				rawData[cmosMinute]) * 60 + rawData[cmosSecond] + 0;
	}

	@property ulong timeStamp() {
		return _timestamp + PIT.seconds;
	}

private:
	ulong _timestamp;
	ubyte _centuryReg;

	void dump(ref ushort[128] rawData) {
		while (updateInProgress) {
		}
		foreach (ubyte idx, ref d; rawData)
			d = read(idx);
	}

	ubyte read(ubyte reg) {
		outp!ubyte(cmosAddress, reg); //(NMI_disable_bit << 7) |
		return inp!ubyte(cmosData);
	}

	void write(ubyte reg, ubyte data) {
		outp!ubyte(cmosAddress, reg); //(NMI_disable_bit << 7) |
		return outp!ubyte(cmosData, data);
	}

	ushort fromBCD(ushort bcd) {
		return (bcd / 16 * 10) + (bcd & 0xf);
	}

	bool updateInProgress() {
		return !!(read(0x0A) & 0x80);
	}

	uint secondsOfYear(ushort years) {
		uint days = 0;
		while (years > 1969) {
			days += 365;
			if (years % 4 == 0) {
				if (years % 100 == 0) {
					if (years % 400 == 0) {
						days++;
					}
				} else {
					days++;
				}
			}
			years--;
		}
		return days * 86_400;
	}

	uint secondsOfMonth(int months, int year) {
		uint days = 0;
		switch (months) {
		case 11:
			days += 30;
		case 10:
			days += 31;
		case 9:
			days += 30;
		case 8:
			days += 31;
		case 7:
			days += 31;
		case 6:
			days += 30;
		case 5:
			days += 31;
		case 4:
			days += 30;
		case 3:
			days += 31;
		case 2:
			days += 28;
			if ((year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0)))
				days++;
		case 1:
			days += 31;
		default:
			break;
		}
		return days * 86_400;
	}
}

//XXX: IsCMOSInited
__gshared bool isCMOSInited = false;

CMOS getCMOS() {
	import data.util : inplaceClass;

	__gshared ubyte[__traits(classInstanceSize, CMOS)] data;
	__gshared CMOS cmos;

	if (!cmos) {
		import acpi.rsdp : rsdp;

		cmos = inplaceClass!CMOS(data, rsdp.fadtInstance.century);
		isCMOSInited = true;
	}
	return cmos;
}
