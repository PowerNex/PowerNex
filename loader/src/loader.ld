OUTPUT_FORMAT(elf64-x86-64)
ENTRY(start)

SECTIONS {
	. = 1M;

	.multiboot : {
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

	/DISCARD/ : {
		*(.eh_frame)
		*(.comment)
	}

	. = ALIGN(0x1000);
}
