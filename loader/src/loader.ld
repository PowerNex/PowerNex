OUTPUT_FORMAT(elf64-x86-64)
ENTRY(start)

PHDRS {
	text PT_LOAD PHDRS FILEHDR;
	data PT_LOAD;
	tls PT_TLS;
	eh_frame PT_GNU_EH_FRAME;
	note PT_NOTE;
}

SECTIONS {
	. = 1M;

	.multiboot : {
		LONG(0x0) /* To force the linker to but .multiboot first*/
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

	.data ALIGN(0x1000) : {
		*(.data .data.*)
	} :data

	.bss ALIGN(0x1000) : {
		*(.bss .bss.*)
	}

	.eh_frame ALIGN(0x1000) : {
		*(.eh_frame .eh_frame.*)
	} :data

	.comment ALIGN(0x1000) : {
		*(.comment .comment.*)
	} :data

	.loaderData ALIGN(0x1000) : {
		pml4 = .; . += 0x1000;
		pml3_0 = .; . += 0x1000;
		pml2_0_0 = .; . += 0x1000;

		stack_end = .; . += 0x1000; stack = .;
		gdt = .; . += 0x1000;
		gdtPointer = .; . += 16;
		multibootPointer = .; multibootPointer += 8;
	}

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

	. = ALIGN(0x1000);
	LOADER_END = .;
}
