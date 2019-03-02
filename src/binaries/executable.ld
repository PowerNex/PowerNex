OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kmain)

PHDRS {
	phdr PT_NULL PHDRS FILEHDR;
	text PT_LOAD;
	data PT_LOAD;
	tls PT_TLS;
}

SECTIONS {
	. = 0x400000;
	.text ALIGN(0x1000) : {
		*(.text .text.*)
	} :text

	.rodata ALIGN(0x1000) : {
		*(.rodata .rodata.*)
	} :text

	.eh_frame ALIGN(0x1000) : {
		*(.eh_frame .eh_frame.*)
	} :text

	.ctors ALIGN(0x1000) : {
		*(.ctors .ctors.*)
	} :data

	.dtors ALIGN(0x1000) : {
		*(.dtors .dtors.*)
	} :data

	.data ALIGN(0x1000) : {
		*(.data .data.*)
	} :data

	.bss ALIGN(0x1000) : {
		*(.bss)
	} :data

	.tdata ALIGN(0x1000) : {
		*(.tdata .tdata.*)
	} :tls :data

	.tbss ALIGN(0x1000) : {
		*(.tbss .tbss.*)
	} :tls :data

	/DISCARD/ : {
		*(.comment)
		*(.note .note.*)
	}
}
