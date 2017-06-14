.text
.code64

.global main
.global multibootPointer

.global start64
start64:
	cli
	mov $0x10, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	xor %rax, %rax
	mov %rax, %dr0

	mov multibootPointer, %edi
	call main

	1:
		hlt
		jmp 1b
