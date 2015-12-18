OUTPUT_FORMAT(elf64-x86-64)
ENTRY(lstart)
KERNEL_LMA = 1M;
KERNEL_VMA = 0xFFFFFFFF80000000;
lstart = start - KERNEL_VMA;
SECTIONS {
	. = KERNEL_LMA;

	.multiboot : AT(ADDR(.multiboot)) {
		LONG(0x0)
		*(.multiboot)
	}

	/*. += 0x100000;*/
	. += KERNEL_VMA;

	.text ALIGN(0x1000) : AT(ADDR(.text) - KERNEL_VMA) {
		*(.text .text.*)
	}

	.rodata ALIGN(0x1000) : AT(ADDR(.rodata) - KERNEL_VMA) {
		*(.initpd)
		*(.rodata .rodata.*)
		*(.rdata)
	}

	.minfo ALIGN(0x1000) : AT(ADDR(.minfo) - KERNEL_VMA) {
		*(.minfo)
	}

	.deh_eh ALIGN(0x1000) : AT(ADDR(.deh_eh) - KERNEL_VMA) {
		*(.deh_eh)
	}

	.dtors.d_dso_dtor ALIGN(0x1000) : AT(ADDR(.dtors.d_dso_dtor) - KERNEL_VMA) {
		*(.dtors .dtors.*)
		 *(.dtors.d_dso_dtor)
	}

	.ctors.d_dso_ctor ALIGN(0x1000) : AT(ADDR(.ctors.d_dso_ctor) - KERNEL_VMA) {
		*(.ctors .ctors.*)
		*(.ctors.d_dso_ctor)
	}

	.eh_frame ALIGN(0x1000) : AT(ADDR(.eh_frame) - KERNEL_VMA) {
		*(.eh_frame)
	}

	.data ALIGN(0x1000) : AT(ADDR(.data) - KERNEL_VMA) {
		*(.padata)
		*(.data .data.*)

		KERNEL_MODULES_START = .;
		*(.KMODULES)
		KERNEL_MODULES_END = .;
	}

	.symbols ALIGN(0x1000) : AT(ADDR(.symbols) - KERNEL_VMA) {
		KERNEL_SYMBOLS_START = .;
		*(.symbols .symbols.*)
		KERNEL_SYMBOLS_END = .;
	}

	.tdata ALIGN(0x1000) : AT(ADDR(.tdata) - KERNEL_VMA) {
		*(.tdata .tdata.*)
	}

	.got ALIGN(0x1000) : AT(ADDR(.got) - KERNEL_VMA) {
		*(.got)
		*(.got.plt)
	}

	.bss ALIGN(0x1000) : AT(ADDR(.bss) - KERNEL_VMA) {
		KERNEL_BSS_START = .;
		*(.COMMON)
		*(.bss)
	}

	.tbss : AT(ADDR(.tbss) - KERNEL_VMA) {
		*(.tbss .tbss.*)
	}

	KERNEL_END = (. + 0xFFF) & 0xFFFFFFFFFFFFF000;

	/DISCARD/ : {
		*(.comment)
		*(.note .note.*)
		*(.rela.*)
	}
}
