.text
.code64

.SET KERNEL_VMA, 0xFFFFFFFF80000000
.SET KERNEL_STACK_SIZE, 8
.extern multiboot_magic
.extern multiboot_ptr
.extern KERNEL_STACK_START
.global start64
.type start64, %function
start64:
	cli
	mov $0x10, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	mov $1f, %rax
	jmp *%rax

1:
	xor %rax, %rax
	mov %rax, %dr0

	mov $KERNEL_STACK_START, %rsp

	mov multiboot_magic, %edi
	mov multiboot_ptr, %esi

	call _Dkmain_entry
	cli

1:
	hlt
	jmp 1b

.size	start64, .-start64
