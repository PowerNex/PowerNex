module CPU.MSR;

enum MSRIdentifiers : uint {
	FSBase = 0xC0000100,
	GSBase = 0xC0000101
}

struct MSR {
	static void Write(MSRIdentifiers ident, ulong value) {
		uint low = cast(uint)value;
		uint high = cast(uint)(value >> 32);
		asm {
			mov EAX, low;
			mov EDX, high;
			mov ECX, ident;
			wrmsr;
		}
	}

	static ulong Read(MSRIdentifiers ident) {
		uint low, high;
		asm {
			mov ECX, ident;
			wrmsr;
			mov high, EDX;
			mov low, EAX;
		}
		return cast(ulong)high << 32UL | low;
	}

	@property static ulong FSBase() {
		return Read(MSRIdentifiers.FSBase);
	}

	@property static ulong FSBase(ulong val) {
		Write(MSRIdentifiers.FSBase, val);
		return val;
	}

	@property static ulong GSBase() {
		return Read(MSRIdentifiers.GSBase);
	}

	@property static ulong GSBase(ulong val) {
		Write(MSRIdentifiers.GSBase, val);
		return val;
	}

}
