.section .initCode, "ax"
.code16
.align 16

.global boot16_location
.set boot16_location, 0x1000

.set boot16_offset, boot16_start - boot16_location

.global boot16_start
.global boot16_end
.global start16

boot16_start:
.type start16, %function
start16:
	cli

	xor %ax, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	# Load GDT
	lgdt (boot16_gdtBase - boot16_offset)

	mov %cr0, %eax
	or $1, %al # Protected Mode Enable
	mov %eax, %cr0

	# Jump to protected mode code
	ljmp $0x8, $(boot16_trampoline - boot16_offset)
.size start16, .-start16

boot16_gdtBase:
	.short (3 * 8 - 1) # limit
	.int (boot16_gdtDescriptors - boot16_offset) # base

boot16_gdtDescriptors:
	.quad 0x0000000000000000 # null
	.quad 0x00CF9A000000FFFF # code
	.quad 0x00CF92000000FFFF # data

.code32
.align 16
.type boot16_trampoline, %function
boot16_trampoline:
	mov $0x10, %eax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss
	ljmp $0x8, $boot32AP
.size boot16_trampoline, .-boot16_trampoline

boot16_end:
