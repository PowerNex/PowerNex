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

static struct CMOS {
public static:
	void init(ubyte centuryReg) {
		_centuryReg = centuryReg;
		retrieveTime();
	}

	void retrieveTime() {
		ushort[128] last;
		ushort[128] rawData;
		_dump(rawData);

		do {
			foreach (idx, val; rawData)
				last[idx] = val;
			_dump(rawData);
		}
		while (last[cmosSecond] != rawData[cmosSecond] || last[cmosMinute] != rawData[cmosMinute]
				|| last[cmosHour] != rawData[cmosHour] || last[cmosDay] != rawData[cmosDay]
				|| last[cmosMonth] != rawData[cmosMonth] || last[cmosYear] != rawData[cmosYear]
				|| last[cmosYear] != rawData[cmosYear] || (_centuryReg && last[_centuryReg] != rawData[_centuryReg]));

		PIT.clear();

		if (!(rawData[cmosRegb] & 0x04)) { // If rawData is BCD
			rawData[cmosSecond] = _fromBCD(rawData[cmosSecond]);
			rawData[cmosMinute] = _fromBCD(rawData[cmosMinute]);
			rawData[cmosHour] = ((rawData[cmosHour] & 0x0F) + (((rawData[cmosHour] & 0x70) / 16) * 10)) | (rawData[cmosHour] & 0x80);
			rawData[cmosDay] = _fromBCD(rawData[cmosDay]);
			rawData[cmosMonth] = _fromBCD(rawData[cmosMonth]);
			rawData[cmosYear] = _fromBCD(rawData[cmosYear]);
			if (_centuryReg)
				rawData[_centuryReg] = _fromBCD(rawData[_centuryReg]);
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

		_timestamp = _secondsOfYear(cast(ushort)(rawData[cmosYear] - 1)) + _secondsOfMonth(rawData[cmosMonth] - 1,
				rawData[cmosYear]) + (rawData[cmosDay] - 1) * 86400 + (rawData[cmosHour]) * 3600 + (rawData[cmosMinute]) * 60
			+ rawData[cmosSecond] + 0;
	}

	@property ulong timeStamp() {
		return _timestamp + PIT.seconds;
	}

private static:
	__gshared ulong _timestamp;
	__gshared ubyte _centuryReg;

	void _dump(ref ushort[128] rawData) {
		while (_updateInProgress) {
		}
		foreach (ubyte idx, ref d; rawData)
			d = _read(idx);
	}

	ubyte _read(ubyte reg) {
		outp!ubyte(cmosAddress, reg); //(NMI_disable_bit << 7) |
		return inp!ubyte(cmosData);
	}

	void _write(ubyte reg, ubyte data) {
		outp!ubyte(cmosAddress, reg); //(NMI_disable_bit << 7) |
		return outp!ubyte(cmosData, data);
	}

	ushort _fromBCD(ushort bcd) {
		return (bcd / 16 * 10) + (bcd & 0xf);
	}

	bool _updateInProgress() {
		return !!(_read(0x0A) & 0x80);
	}

	uint _secondsOfYear(ushort years) {
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

	uint _secondsOfMonth(int months, int year) {
		uint days = 0;
		switch (months) {
		case 11:
			days += 30;
			goto case;
		case 10:
			days += 31;
			goto case;
		case 9:
			days += 30;
			goto case;
		case 8:
			days += 31;
			goto case;
		case 7:
			days += 31;
			goto case;
		case 6:
			days += 30;
			goto case;
		case 5:
			days += 31;
			goto case;
		case 4:
			days += 30;
			goto case;
		case 3:
			days += 31;
			goto case;
		case 2:
			days += 28;
			if ((year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0)))
				days++;
			goto case;
		case 1:
			days += 31;
			break;
		default:
			break;
		}
		return days * 86_400;
	}
}
