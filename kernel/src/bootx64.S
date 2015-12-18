.text
.code64

.SET KERNEL_VMA, 0xFFFFFFFF80000000
.SET KERNEL_STACK_SIZE, 8
.extern multiboot_magic
.extern multiboot_ptr
.extern KERNEL_STACK_START
.global start64
start64:
	cli
	mov $0x10, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	mov $.himem, %rax
	jmp %rax
.himem:
	xor %rax, %rax
	mov %rax, %dr0

	mov $KERNEL_STACK_START, %rsp

	mov (multiboot_magic - KERNEL_VMA), %edi
	mov (multiboot_ptr - KERNEL_VMA), %esi
	call _Dkmain_entry
	cli

.hang:
	hlt
	jmp .hang

.bss
