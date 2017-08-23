.extern KERNEL_LMA
.SET KERNEL_VMA, 0xFFFFFFFF80000000

#8*0x1000 = 32KiB
.SET KERNEL_STACK_SIZE, 8

.section .data
.global multiboot_magic
multiboot_magic:
	.int 0
.global multiboot_ptr
multiboot_ptr:
	.int 0

.section .rodata
# TODO: Define name the constants
.global gdt
.align 16
gdt:
	.quad 0

	gdtCode64:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xA09A00
		# AF9A000000FFFF
	gdtData64:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xA09200
		# AF92000000FFFF

	gdtCode32:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xC09A00
		# CF9A000000FFFF
	gdtData32:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xC09200
		# CF92000000FFFF

gdtPointer:
	.word . - gdt - 1
	.int gdt - KERNEL_VMA, 0

.section .bss
.align 0x1000

.global PML4

PML4:
	.space 0x1000

PML3_bootOnly:
	.space 0x1000
PML2_bootOnly:
	.space 0x1000
PML1_bootOnly1:
	.space 0x1000
PML1_bootOnly2:
	.space 0x1000

PML3_special:
	.space 0x1000
PML2_special:
	.space 0x1000
PML1_special:
	.space 0x1000

PML3_kernel:
	.space 0x1000
PML2_kernel:
	.space 0x1000
PML1_kernel:
	.space 32*0x1000

# TODO: Move stack to better place
.global KERNEL_STACK
.global KERNEL_STACK_START
KERNEL_STACK:
	.space 0x1000 * (KERNEL_STACK_SIZE - 1)
KERNEL_STACK_START:
