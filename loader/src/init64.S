.text
.code64

.global main
.global multibootPointer

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

	xor %rax, %rax
	mov %rax, %dr0

	mov multibootPointer, %edi
	call main

	1:
		hlt
		jmp 1b
.size start64, .-start64


.global __dmd_personality_v0
.type __dmd_personality_v0, %function
__dmd_personality_v0:
	hlt
	jmp __dmd_personality_v0
.size __dmd_personality_v0, .-__dmd_personality_v0
