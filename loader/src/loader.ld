OUTPUT_FORMAT(elf64-x86-64)
ENTRY(start)

SECTIONS {
	. = 1M;

	.multiboot : {
		LONG(0x0) /* To force the linker to but .multiboot first*/
		*(.multiboot)
	}

	.text ALIGN(0x1000) : {
		*(.text .text.*)
		*(.rodata .rodata.*)
	}

	.data ALIGN(0x1000) : {
		*(.data .data.*)
	}

	.bss ALIGN(0x1000) : {
		*(.bss .bss.*)
	}

	.loaderData ALIGN(0x1000) : {
		pml4 = .; . += 0x1000;
		pml3_0 = .; . += 0x1000;
		pml2_0_0 = .; . += 0x1000;

		stack_end = .; . += 0x1000; stack = .;
		gdt = .; . += 0x1000;
		gdtPointer = .; . += 16;
		multibootPointer = .; multibootPointer += 8;
	}

	/DISCARD/ : {
		*(.eh_frame)
		*(.comment)
		*(.gcc_except_table)
		*(.debug_*)
		*(.ctors.d_dso_ctor)
		*(.dtors.d_dso_dtor)
	}

	. = ALIGN(0x1000);
}
