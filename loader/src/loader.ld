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

	.multiboot : {
		LONG(0x0) /* To force the linker to put .multiboot first*/
		*(.multiboot)
	} :text

	.init : {
		*(.initCode .initCode.*)
	}

	.text : {
		*(.text .text.*)
	} :text

	.rodata : {
		*(.rodata .rodata.*)
	} :text

	.eh_frame : {
		*(.eh_frame .eh_frame.*)
	} :text

	.ctors : {
		CTORS_START = .;
		*(.ctors .ctors.*)
		CTORS_END = .;
	} :data

	.dtors : {
		DTORS_START = .;
		*(.dtors .dtors.*)
		DTORS_END = .;
	} :data

	.data : {
		*(.data .data.*)
	} :data

	.bss : {
		*(.bss .bss.*)
	} :data

	.tdata : {
		TDATA_START = .;
		*(.tdata .tdata.*)
		TDATA_END = .;
	} :tls :data

	.tbss : {
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
