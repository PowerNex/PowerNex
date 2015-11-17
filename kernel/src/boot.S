.extern KERNEL_LMA
.SET KERNEL_VMA, 0xFFFFFFFF80000000

#8*0x1000 = 32KiB
.SET KERNEL_STACK_SIZE, 8
.extern KERNEL_MODULES_START
.extern KERNEL_MODULES_END
.extern KERNEL_SYMBOLS_START
.extern KERNEL_SYMBOLS_END
.extern KERNEL_BSS_START
.extern KERNEL_END

.set MULTIBOOT2_HEADER_MAGIC, 0xe85250d6
.set MULTIBOOT_ARCHITECTURE_I386, 0
.set MULTIBOOT_HEADER_TAG_ADDRESS, 2
.set MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS, 3
.set MULTIBOOT_HEADER_TAG_END, 0

.section .multiboot
.align 8
multiboot2_header:
	.int MULTIBOOT2_HEADER_MAGIC
	.int MULTIBOOT_ARCHITECTURE_I386
	.int (.end - multiboot2_header)
	.int -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT_ARCHITECTURE_I386 + (.end - multiboot2_header))

	.short MULTIBOOT_HEADER_TAG_ADDRESS
	.short 0
	.int 24
	.int multiboot2_header
	.int KERNEL_LMA
	.int (KERNEL_BSS_START - KERNEL_VMA)
	.int (KERNEL_END - KERNEL_VMA)

	.short MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS
	.short 0
	.int 12
	.int start - KERNEL_VMA

	.short MULTIBOOT_HEADER_TAG_END
	.short 0
	.int 0
.end:

.text
.code32

.extern start64
.global start
start:
	cli

	movl %eax, (multiboot_magic - KERNEL_VMA)
	movl %ebx, (multiboot_ptr - KERNEL_VMA)

	# Check to check if we can check if x64 is supported
	mov $0x80000000, %eax
	cpuid
	cmp $0x80000001, %eax
		jb .notx64Capable

	# Check so that x64 is supported
	mov $0x80000001, %eax
	cpuid
	test $(1 << 29), %edx
		jz .notx64Capable

	# Enable PAE
	mov %cr4, %eax
	bts $5, %eax
	mov %eax, %cr4

	# Set long mode bit in EFER MSR
	mov $0xC0000080, %ecx # Refers to EFER MSR
	rdmsr
	bts $11, %eax
	bts $8, %eax
	bts $0, %eax
	wrmsr

	mov $(PML4 - KERNEL_VMA), %eax
	mov %eax, %cr3

	# Enable paging and write protected
	mov %cr0, %eax
	bts $31, %eax
	bts $16, %eax
	mov %eax, %cr0

	# Load x64 GDT
	lgdt (gdtPointer - KERNEL_VMA)
	# Jump into x64
	ljmp $0x8, $(start64 - KERNEL_VMA)

.notx64Capable:
	mov $0x4A, %ah
	mov $0xB8000, %edi
	mov $(x64NotSupported_msg - KERNEL_VMA), %esi

.loop:
	lodsb
	test %al, %al
		jz .hidecursor
	stosw
	jmp .loop

.hidecursor:
	mov $0x0F, %al
	mov $0x3D4, %dx
	out %al, %dx

	mov $0xFF, %al
	mov $0x3D5, %dx
	out %al, %dx

	mov $0x0E, %al
	mov $0x3D4, %dx
	out %al, %dx

	mov $0xFF, %al
	mov $0x3D5, %dx
	out %al, %dx

.hlt:
	cli
	hlt
	jmp .hlt

.section .data
.global multiboot_magic
multiboot_magic:
	.int 0
.global multiboot_ptr
multiboot_ptr:
	.int 0

x64NotSupported_msg:
	.ascii "                                                                                "
	.ascii "                   _____                       _   _                            "
	.ascii "                  |  __ \\                     | \\ | |                           "
	.ascii "                  | |__) |____      _____ _ __|  \\| | _____  __                 "
	.ascii "                  |  ___/ _ \\ \\ /\\ / / _ \\ '__| . ` |/ _ \\ \\/ /                 "
	.ascii "                  | |  | (_) \\ V  V /  __/ |  | |\\  |  __/>  <                  "
	.ascii "                  |_|   \\___/ \\_/\\_/ \\___|_|  |_| \\_|\\___/_/\\_\\                 "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                   *The current setup can not run 64-bit code*                  "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  Please run PowerNex in a VM which supports it                 "
	.ascii "                  Examples of VM that are supported are:                        "
	.ascii "                                                                                "
	.ascii "                  * QEMU       - qemu.org                                       "
	.ascii "                  * Bochs      - bochs.sourceforge.net                          "
	.ascii "                  * VirtualBox - virtualbox.org                                 "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  If you believe that you should see this                       "
	.ascii "                  message because of an error.                                  "
	.ascii "                  Please report it to: vild.io/powernex                         "
	.ascii "                                   or: powernex@vild.io                         "
	.ascii "                                                                                "
	.byte 0

.section .padata
.align 0x1000
.SET PRESENT,     0x1
.SET WRITEABLE,   0x2
.SET UNKNOWN_BIT, 0x100
.SET PW, PRESENT + WRITEABLE
.SET ATTR, (- KERNEL_VMA + PW)
.SET STACK_ATTR, (- KERNEL_VMA + PW + UNKNOWN_BIT)

.macro mapPage from, to
	.int \from + PW + UNKNOWN_BIT, 0
	.if \to-\from
		mapPage "(\from+0x1000)", \to
	.endif
.endm

# Kinda stole this from https://github.com/Bloodmanovski/Trinix/blob/master/KernelLand/Kernel/Architectures/x86_64/Boot/Boot.s

PML4:
	.int PDP + ATTR, 0 # Identity map for low 4MB
	.space (319) * 8
	.int PDP_STACK + ATTR, 0 # Kernel stack
	.space (187) * 8

	.int PML4 + ATTR, 0 # Fractal mapping
	.quad 0
	.quad 0
	.int PDP_HIGH + ATTR, 0 # Map low 4MB to kernel base

PDP:
	.int PD + ATTR, 0
	.space 511 * 8

PDP_STACK:
	.int PD_STACK + ATTR, 0
	.space 511*8

PDP_HIGH:
	.space 510*8
	.int PD + ATTR, 0
	.quad 0

PD:
	.int PT_1 + ATTR, 0
	.int PT_2 + ATTR, 0
	.int PT_3 + ATTR, 0
	.int PT_4 + ATTR, 0
	.int PT_5 + ATTR, 0
	.int PT_6 + ATTR, 0
	.int PT_7 + ATTR, 0
	.int PT_8 + ATTR, 0
	.int PT_9 + ATTR, 0
	.space 503*8

PD_STACK:
	.int PT_STACK + ATTR, 0
	.space 511*8


.macro mapStack from, to
	.if \to-\from
		.int \from + STACK_ATTR, 0
		mapStack "(\from+0x1000)", \to
	.endif
.endm


PT_STACK:
	.quad 0
	mapStack (KERNEL_STACK), (KERNEL_STACK + ((KERNEL_STACK_SIZE - 1) * 0x1000))
	.space (512 - KERNEL_STACK_SIZE)*8

PT_1:
	mapPage (0x1000 * (0   +    0)), (0x1000 * (64  +    0))
	mapPage (0x1000 * (65  +    0)), (0x1000 * (128 +    0))
	mapPage (0x1000 * (129 +    0)), (0x1000 * (192 +    0))
	mapPage (0x1000 * (193 +    0)), (0x1000 * (256 +    0))
	mapPage (0x1000 * (257 +    0)), (0x1000 * (320 +    0))
	mapPage (0x1000 * (321 +    0)), (0x1000 * (384 +    0))
	mapPage (0x1000 * (385 +    0)), (0x1000 * (448 +    0))
	mapPage (0x1000 * (449 +    0)), (0x1000 * (511 +    0))

PT_2:
	mapPage (0x1000 * (0   +  512)), (0x1000 * (64  +  512))
	mapPage (0x1000 * (65  +  512)), (0x1000 * (128 +  512))
	mapPage (0x1000 * (129 +  512)), (0x1000 * (192 +  512))
	mapPage (0x1000 * (193 +  512)), (0x1000 * (256 +  512))
	mapPage (0x1000 * (257 +  512)), (0x1000 * (320 +  512))
	mapPage (0x1000 * (321 +  512)), (0x1000 * (384 +  512))
	mapPage (0x1000 * (385 +  512)), (0x1000 * (448 +  512))
	mapPage (0x1000 * (449 +  512)), (0x1000 * (511 +  512))

PT_3:
	mapPage (0x1000 * (0   + 1024)), (0x1000 * (64  + 1024))
	mapPage (0x1000 * (65  + 1024)), (0x1000 * (128 + 1024))
	mapPage (0x1000 * (129 + 1024)), (0x1000 * (192 + 1024))
	mapPage (0x1000 * (193 + 1024)), (0x1000 * (256 + 1024))
	mapPage (0x1000 * (257 + 1024)), (0x1000 * (320 + 1024))
	mapPage (0x1000 * (321 + 1024)), (0x1000 * (384 + 1024))
	mapPage (0x1000 * (385 + 1024)), (0x1000 * (448 + 1024))
	mapPage (0x1000 * (449 + 1024)), (0x1000 * (511 + 1024))

PT_4:
	mapPage (0x1000 * (0   + 1536)), (0x1000 * (64  + 1536))
	mapPage (0x1000 * (65  + 1536)), (0x1000 * (128 + 1536))
	mapPage (0x1000 * (129 + 1536)), (0x1000 * (192 + 1536))
	mapPage (0x1000 * (193 + 1536)), (0x1000 * (256 + 1536))
	mapPage (0x1000 * (257 + 1536)), (0x1000 * (320 + 1536))
	mapPage (0x1000 * (321 + 1536)), (0x1000 * (384 + 1536))
	mapPage (0x1000 * (385 + 1536)), (0x1000 * (448 + 1536))
	mapPage (0x1000 * (449 + 1536)), (0x1000 * (511 + 1536))

PT_5:
	mapPage (0x1000 * (0   + 2048)), (0x1000 * (64  + 2048))
	mapPage (0x1000 * (65  + 2048)), (0x1000 * (128 + 2048))
	mapPage (0x1000 * (129 + 2048)), (0x1000 * (192 + 2048))
	mapPage (0x1000 * (193 + 2048)), (0x1000 * (256 + 2048))
	mapPage (0x1000 * (257 + 2048)), (0x1000 * (320 + 2048))
	mapPage (0x1000 * (321 + 2048)), (0x1000 * (384 + 2048))
	mapPage (0x1000 * (385 + 2048)), (0x1000 * (448 + 2048))
	mapPage (0x1000 * (449 + 2048)), (0x1000 * (511 + 2048))

PT_6:
	mapPage (0x1000 * (0   + 2560)), (0x1000 * (64  + 2560))
	mapPage (0x1000 * (65  + 2560)), (0x1000 * (128 + 2560))
	mapPage (0x1000 * (129 + 2560)), (0x1000 * (192 + 2560))
	mapPage (0x1000 * (193 + 2560)), (0x1000 * (256 + 2560))
	mapPage (0x1000 * (257 + 2560)), (0x1000 * (320 + 2560))
	mapPage (0x1000 * (321 + 2560)), (0x1000 * (384 + 2560))
	mapPage (0x1000 * (385 + 2560)), (0x1000 * (448 + 2560))
	mapPage (0x1000 * (449 + 2560)), (0x1000 * (511 + 2560))

PT_7:
	mapPage (0x1000 * (0   + 3072)), (0x1000 * (64  + 3072))
	mapPage (0x1000 * (65  + 3072)), (0x1000 * (128 + 3072))
	mapPage (0x1000 * (129 + 3072)), (0x1000 * (192 + 3072))
	mapPage (0x1000 * (193 + 3072)), (0x1000 * (256 + 3072))
	mapPage (0x1000 * (257 + 3072)), (0x1000 * (320 + 3072))
	mapPage (0x1000 * (321 + 3072)), (0x1000 * (384 + 3072))
	mapPage (0x1000 * (385 + 3072)), (0x1000 * (448 + 3072))
	mapPage (0x1000 * (449 + 3072)), (0x1000 * (511 + 3072))

PT_8:
	mapPage (0x1000 * (0   + 3584)), (0x1000 * (64  + 3584))
	mapPage (0x1000 * (65  + 3584)), (0x1000 * (128 + 3584))
	mapPage (0x1000 * (129 + 3584)), (0x1000 * (192 + 3584))
	mapPage (0x1000 * (193 + 3584)), (0x1000 * (256 + 3584))
	mapPage (0x1000 * (257 + 3584)), (0x1000 * (320 + 3584))
	mapPage (0x1000 * (321 + 3584)), (0x1000 * (384 + 3584))
	mapPage (0x1000 * (385 + 3584)), (0x1000 * (448 + 3584))
	mapPage (0x1000 * (449 + 3584)), (0x1000 * (511 + 3584))

PT_9:
	mapPage (0x1000 * (0   + 4096)), (0x1000 * (64  + 4096))
	mapPage (0x1000 * (65  + 4096)), (0x1000 * (128 + 4096))
	mapPage (0x1000 * (129 + 4096)), (0x1000 * (192 + 4096))
	mapPage (0x1000 * (193 + 4096)), (0x1000 * (256 + 4096))
	mapPage (0x1000 * (257 + 4096)), (0x1000 * (320 + 4096))
	mapPage (0x1000 * (321 + 4096)), (0x1000 * (384 + 4096))
	mapPage (0x1000 * (385 + 4096)), (0x1000 * (448 + 4096))
	mapPage (0x1000 * (449 + 4096)), (0x1000 * (511 + 4096))


.section .padata
.global KERNEL_STACK
KERNEL_STACK:
	.space 0x1000 * (KERNEL_STACK_SIZE - 1)


# TODO: Define name the constants
.global gdt
.align 16
gdt:
	.quad 0

	gdtCode64:
		.long 0x0000FFFF
		.long 0x000F0000 + 0xA09A00
	gdtData64:
		.long 0x0000FFFF
		.long 0x000F0000 + 0xA09200

	gdtCode32:
		.long 0x0000FFFF
		.long 0x000F0000 + 0xC09A00
	gdtData32:
		.long 0x0000FFFF
		.long 0x000F0000 + 0xC09200

gdtPointer:
	.word . - gdt - 1
	.int gdt - KERNEL_VMA, 0
