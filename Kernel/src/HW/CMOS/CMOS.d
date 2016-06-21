module HW.CMOS.CMOS;

import IO.Port;

private enum {
	CMOS_ADDRESS = 0x70,
	CMOS_DATA = 0x71,

	CMOS_SECOND = 0,
	CMOS_MINUTE = 2,
	CMOS_HOUR = 4,
	CMOS_DAY = 7,
	CMOS_MONTH = 8,
	CMOS_YEAR = 9,

	CMOS_REGA = 0x0A,
	CMOS_REGB = 0x0B
}

class CMOS {
public:
	this(ubyte centuryReg) {
		this.centuryReg = centuryReg;
		RetrieveTime();
	}

	void RetrieveTime() {
		import CPU.PIT;

		ushort[128] last;
		ushort[128] data;
		dump(data);

		do {
			foreach (idx, val; data)
				last[idx] = val;
			dump(data);
		}
		while (last[CMOS_SECOND] != data[CMOS_SECOND] || last[CMOS_MINUTE] != data[CMOS_MINUTE]
				|| last[CMOS_HOUR] != data[CMOS_HOUR] || last[CMOS_DAY] != data[CMOS_DAY]
				|| last[CMOS_MONTH] != data[CMOS_MONTH] || last[CMOS_YEAR] != data[CMOS_YEAR]
				|| last[CMOS_YEAR] != data[CMOS_YEAR] || (centuryReg && last[centuryReg] != data[centuryReg]));

		PIT.Clear();

		if (!(data[CMOS_REGB] & 0x04)) { // If data is BCD
			data[CMOS_SECOND] = fromBCD(data[CMOS_SECOND]);
			data[CMOS_MINUTE] = fromBCD(data[CMOS_MINUTE]);
			data[CMOS_HOUR] = ((data[CMOS_HOUR] & 0x0F) + (((data[CMOS_HOUR] & 0x70) / 16) * 10)) | (data[CMOS_HOUR] & 0x80);
			data[CMOS_DAY] = fromBCD(data[CMOS_DAY]);
			data[CMOS_MONTH] = fromBCD(data[CMOS_MONTH]);
			data[CMOS_YEAR] = fromBCD(data[CMOS_YEAR]);
			if (centuryReg)
				data[centuryReg] = fromBCD(data[centuryReg]);
		}

		if (!(data[CMOS_REGB] & 0x02) && (data[CMOS_HOUR] & 0x80)) // am/pm -> 24 hours
			data[CMOS_HOUR] = ((data[CMOS_HOUR] & 0x7F) + 12) % 24;

		if (centuryReg)
			data[CMOS_YEAR] += data[centuryReg] * 100;
		else {
			import Data.String;

			string year = __DATE__[$ - 4 .. $];
			ushort currentYear = cast(ushort)atoi(year);

			data[CMOS_YEAR] += (currentYear / 100) * 100;
			if (data[CMOS_YEAR] < currentYear)
				data[CMOS_YEAR] += 100;
		}

		timestamp = secondsOfYear(cast(ushort)(data[CMOS_YEAR] - 1)) + secondsOfMonth(data[CMOS_MONTH] - 1,
				data[CMOS_YEAR]) + (data[CMOS_DAY] - 1) * 86400 + (data[CMOS_HOUR]) * 3600 + (data[CMOS_MINUTE]) * 60 + data[CMOS_SECOND]
			+ 0;
	}

	@property ulong TimeStamp() {
		import CPU.PIT;

		return timestamp + PIT.Seconds;
	}

private:
	ulong timestamp;
	ubyte centuryReg;

	void dump(ref ushort[128] rawData) {
		while (updateInProgress) {
		}
		foreach (ubyte idx, ref d; rawData)
			d = read(idx);
	}

	ubyte read(ubyte reg) {
		Out!ubyte(CMOS_ADDRESS, reg); //(NMI_disable_bit << 7) |
		return In!ubyte(CMOS_DATA);
	}

	void write(ubyte reg, ubyte data) {
		Out!ubyte(CMOS_ADDRESS, reg); //(NMI_disable_bit << 7) |
		return Out!ubyte(CMOS_DATA, data);
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

CMOS GetCMOS() {
	import Data.Util : InplaceClass;

	__gshared ubyte[__traits(classInstanceSize, CMOS)] data;
	__gshared CMOS cmos;

	if (!cmos) {
		import ACPI.RSDP : rsdp;

		cmos = InplaceClass!CMOS(data, rsdp.FADTInstance.Century);
	}
	return cmos;
}
