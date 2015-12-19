module linker;

import data.address;

/*
	You have to do it like this because the linker will put the variable at the address.
	*It will not set the address as a value of the variable.*
*/
private extern(C) extern __gshared {
	ubyte KERNEL_LMA;
	ubyte KERNEL_VMA;
	ubyte KERNEL_END;
	ubyte KERNEL_SYMBOLS_START;
	ubyte KERNEL_SYMBOLS_END;
	ubyte KERNEL_MODULES_START;
	ubyte KERNEL_MODULES_END;
}

static struct Linker {
public:
	@property static PhysAddress KernelPhysStart()    { return PhysAddress(&KERNEL_LMA); }
	@property static PhysAddress KernelStart()        { return PhysAddress(&KERNEL_VMA); }
	@property static PhysAddress KernelEnd()          { return PhysAddress(&KERNEL_END); }
	@property static PhysAddress KernelSymbolsStart() { return PhysAddress(&KERNEL_SYMBOLS_START); }
	@property static PhysAddress KernelSymbolsEnd()   { return PhysAddress(&KERNEL_SYMBOLS_END); }
	@property static PhysAddress KernelModulesStart() { return PhysAddress(&KERNEL_MODULES_START); }
	@property static PhysAddress KernelModulesEnd()   { return PhysAddress(&KERNEL_MODULES_END); }
}
