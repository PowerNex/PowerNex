module CPU.MSR;

enum MSRIdentifiers : uint {
	EFER = 0xC0000080,
	Star = 0xC0000081,
	LStar = 0xC0000082,
	CStar = 0xC0000083,
	SFMask = 0xC0000084,
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

	mixin(generateGetterSetter());

private:
	static string generateGetterSetter() {
		if (!__ctfe)
			return "";
		template generateGetterSetterEntry(alias item) {
			enum generateGetterSetterEntry = `@property static ulong ` ~ item ~ `() { return Read(MSRIdentifiers.` ~ item
					~ `); }
@property static ulong ` ~ item ~ `(ulong val) { Write(MSRIdentifiers.` ~ item ~ `, val); return val;	}`;
		}

		string output;
		foreach (item; __traits(allMembers, MSRIdentifiers))
			output ~= generateGetterSetterEntry!item;

		return output;
	}
}
