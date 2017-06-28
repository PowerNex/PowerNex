OUTPUT_FORMAT(elf64-x86-64)
ENTRY(start)

PHDRS {
	text PT_LOAD PHDRS FILEHDR;
	data PT_LOAD;
	bss PT_LOAD;
	tls PT_TLS;
}

SECTIONS {
	. = 1M;

	.multiboot : {
		LONG(0x0) /* To force the linker to put .multiboot first*/
		*(.multiboot)
	} :text

	.text ALIGN(0x1000) : {
		*(.text .text.*)
	} :text

	.rodata ALIGN(0x1000) : {
		*(.rodata .rodata.*)
	} :text

	.ctors ALIGN(0x1000) : {
		CTORS_START = .;
		*(.ctors .ctors.*)
		CTORS_END = .;
	} :data

	.dtors ALIGN(0x1000) : {
		DTORS_START = .;
		*(.dtors .dtors.*)
		DTORS_END = .;
	} :data

	.eh_frame ALIGN(0x1000) : {
		*(.eh_frame .eh_frame.*)
	} :data

	.data ALIGN(0x1000) : {
		*(.data .data.*)
	} :data

	.tdata ALIGN(0x1000) :  {
		TDATA_START = .;
		*(.tdata .tdata.*)
		TDATA_END = .;
	} :text :tls

	.tbss ALIGN(0x1000) : {
		TBSS_START = .;
		*(.tbss .tbss.*)
		TBSS_END = .;
	} :tls

	.bss ALIGN(0x1000) : {
		*(.bss .bss.*)
	} :bss

	.loaderData ALIGN(0x1000) : {
		loaderData_start = .;
		*(.loaderData .loaderData.*)
		loaderData_end = .;
	} :bss

	/DISCARD/ : {
		*(.comment)
		*(.note .note.*)
		*(.rela.*)
		*(.debug_*)
	}

	. = ALIGN(0x1000);
	LOADER_END = .;
}
