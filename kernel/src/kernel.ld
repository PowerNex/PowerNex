OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kmain)
KERNEL_LMA = 16M;
KERNEL_VMA = 0xFFFFFFFF80000000;

PHDRS {
	phdr PT_NULL PHDRS FILEHDR;
	text PT_LOAD;
	data PT_LOAD;
	tls PT_TLS;
}

SECTIONS {
	. = KERNEL_VMA;

	.text ALIGN(0x1000) : AT(ADDR(.text) - KERNEL_VMA + KERNEL_LMA) {
		*(.text .text.*)
	} :text

	.rodata ALIGN(0x1000) : AT(ADDR(.rodata) - KERNEL_VMA + KERNEL_LMA) {
		*(.rodata .rodata.*)
	} :text

	.eh_frame ALIGN(0x1000) : AT(ADDR(.eh_frame) - KERNEL_VMA + KERNEL_LMA) {
		*(.eh_frame .eh_frame.*)
	} :text

	.ctors ALIGN(0x1000) : AT(ADDR(.ctors) - KERNEL_VMA + KERNEL_LMA) {
		CTORS_START = .;
		*(.ctors .ctors.*)
		CTORS_END = .;
	} :data

	.dtors ALIGN(0x1000) : AT(ADDR(.dtors) - KERNEL_VMA + KERNEL_LMA) {
		DTORS_START = .;
		*(.dtors .dtors.*)
		DTORS_END = .;
	} :data

	.data ALIGN(0x1000) : AT(ADDR(.data) - KERNEL_VMA + KERNEL_LMA) {
		*(.data .data.*)
	} :data

	.bss ALIGN(0x1000) : AT(ADDR(.bss) - KERNEL_VMA + KERNEL_LMA) {
		*(.bss)
	} :data

	.tdata ALIGN(0x1000) : AT(ADDR(.tdata) - KERNEL_VMA + KERNEL_LMA) {
		*(.tdata .tdata.*)
	} :tls :data

	.tbss : AT(ADDR(.tbss) - KERNEL_VMA + KERNEL_LMA) {
		TBSS_START = .;
		*(.tbss .tbss.*)
		TBSS_END = .;
	} :tls :data

	KERNEL_END = (. + 0xFFF) & 0xFFFFFFFFFFFFF000;

	/DISCARD/ : {
		*(.comment)
		*(.note .note.*)
	}
}
