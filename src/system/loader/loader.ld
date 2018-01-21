OUTPUT_FORMAT(elf64-x86-64)
ENTRY(start)

PHDRS {
	phdr PT_LOAD PHDRS FILEHDR;
	text PT_LOAD;
	data PT_LOAD;
	tls PT_TLS;
}

SECTIONS {
	. = 1M;

	.multiboot ALIGN(16) : {
		LONG(0x0) /* To force the linker to put .multiboot first*/
		*(.multiboot)
	} :text

	.init ALIGN(16) : {
		*(.initCode .initCode.*)
	}

	.text ALIGN(16) : {
		*(.text .text.*)
	} :text

	.rodata ALIGN(16) : {
		*(.rodata .rodata.*)
	} :text

	.eh_frame ALIGN(16) : {
		*(.eh_frame .eh_frame.*)
	} :text

	.ctors ALIGN(16) : {
		CTORS_START = .;
		*(.ctors .ctors.*)
		CTORS_END = .;
	} :data

	.dtors ALIGN(16) : {
		DTORS_START = .;
		*(.dtors .dtors.*)
		DTORS_END = .;
	} :data

	.data ALIGN(16) : {
		*(.data .data.*)
	} :data

	.bss ALIGN(16) : {
		*(.bss .bss.*)
	} :data

	.tdata ALIGN(16) : {
		TDATA_START = .;
		*(.tdata .tdata.*)
		TDATA_END = .;
	} :tls :data

	.tbss ALIGN(16) : {
		TBSS_START = .;
		*(.tbss .tbss.*)
		*(.tcommon)
		TBSS_END = .;
	} :tls :data

	/DISCARD/ : {
		*(.comment)
		*(.note .note.*)
	}
}
