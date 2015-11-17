.text
.code64

.SET KERNEL_VMA, 0xFFFFFFFF80000000
.SET KERNEL_STACK_SIZE, 8
.extern multiboot_magic
.extern multiboot_ptr
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

	mov $0xFFFFFFFF80010000 + KERNEL_STACK_SIZE * 0x1000, %rsp

	mov (multiboot_magic - KERNEL_VMA), %edi
	mov (multiboot_ptr - KERNEL_VMA), %esi
	call _Dkmain_entry
	cli

.hang:
	hlt
	jmp .hang

.bss
