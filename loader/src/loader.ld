OUTPUT_FORMAT(elf64-x86-64)
ENTRY(start)

PHDRS {
	phdr PT_LOAD PHDRS FILEHDR;
	load PT_LOAD;
	tls PT_TLS;
}

SECTIONS {
	. = 1M;

	.multiboot : {
		LONG(0x0) /* To force the linker to put .multiboot first*/
		*(.multiboot)
	} :load

	.text ALIGN(0x1000) : {
		*(.text .text.*)
	} :load

	.rodata ALIGN(0x1000) : {
		*(.rodata .rodata.*)
	} :load

	.ctors ALIGN(0x1000) : {
		CTORS_START = .;
		*(.ctors .ctors.*)
		CTORS_END = .;
	} :load

	.dtors ALIGN(0x1000) : {
		DTORS_START = .;
		*(.dtors .dtors.*)
		DTORS_END = .;
	} :load

	.eh_frame ALIGN(0x1000) : {
		*(.eh_frame .eh_frame.*)
	} :load

	.data ALIGN(0x1000) : {
		*(.data .data.*)
	} :load

	.bss ALIGN(0x1000) : {
		*(.bss .bss.*)
	} :load

	.loaderData ALIGN(0x1000) : {
		loaderData_start = .;
		*(.loaderData .loaderData.*)
		loaderData_end = .;
	} :load

	.tdata ALIGN(0x1000) :  {
		TDATA_START = .;
		*(.tdata .tdata.*)
		TDATA_END = .;
	} :tls :load

	.tbss : {
		TBSS_START = .;
		*(.tbss .tbss.*)
		TBSS_END = .;
	} :tls :load

	/DISCARD/ : {
		*(.comment)
		*(.note .note.*)
		*(.rela.*)
		*(.debug_*)
	}
}
