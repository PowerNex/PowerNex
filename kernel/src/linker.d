module linker;

/*
	You have to do it like this because the linker will put the variable at the address.
	*It will not set the address as a value of the variable.*
*/
private extern(C) extern __gshared {
	ubyte KERNEL_VMA;
	ubyte KERNEL_END;
	ubyte KERNEL_SYMBOLS_START;
	ubyte KERNEL_SYMBOLS_END;
	ubyte KERNEL_MODULES_START;
	ubyte KERNEL_MODULES_END;
}

static struct Linker {
public:
	@property static ulong KernelStart()        { return cast(ulong)&KERNEL_VMA; }
	@property static ulong KernelEnd()          { return cast(ulong)&KERNEL_END; }
	@property static ulong KernelSymbolsStart() { return cast(ulong)&KERNEL_SYMBOLS_START; }
	@property static ulong KernelSymbolsEnd()   { return cast(ulong)&KERNEL_SYMBOLS_END; }
	@property static ulong KernelModulesStart() { return cast(ulong)&KERNEL_MODULES_START; }
	@property static ulong KernelModulesEnd()   { return cast(ulong)&KERNEL_MODULES_END; }
}
