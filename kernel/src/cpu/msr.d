module cpu.msr;

enum MSRIdentifiers : uint {
	efer = 0xC0000080,
	star = 0xC0000081,
	lStar = 0xC0000082,
	cStar = 0xC0000083,
	sfMask = 0xC0000084,
	fsBase = 0xC0000100,
	gsBase = 0xC0000101
}

struct MSR {
	static void write(MSRIdentifiers ident, ulong value) {
		uint low = cast(uint)value;
		uint high = cast(uint)(value >> 32);
		asm pure nothrow {
			mov EAX, low;
			mov EDX, high;
			mov ECX, ident;
			wrmsr;
		}
	}

	static ulong read(MSRIdentifiers ident) {
		uint low, high;
		asm pure nothrow {
			mov ECX, ident;
			rdmsr;
			mov high, EDX;
			mov low, EAX;
		}
		return cast(ulong)high << 32UL | low;
	}

	mixin(_generateGetterSetter());

private:
	static string _generateGetterSetter() {
		if (!__ctfe)
			return "";
		template _generateGetterSetterEntry(alias item) {
			enum _generateGetterSetterEntry = `@property static ulong ` ~ item ~ `() { return read(MSRIdentifiers.`
					~ item ~ `); }
@property static ulong ` ~ item ~ `(ulong val) { write(MSRIdentifiers.` ~ item ~ `, val); return val;	}`;
		}

		string output;
		foreach (item; __traits(allMembers, MSRIdentifiers))
			output ~= _generateGetterSetterEntry!item;

		return output;
	}
}
