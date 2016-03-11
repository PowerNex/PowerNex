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

.remapIRQ:
.SET MasterControl, 0x20
.SET MasterData, 0x21
.SET SlaveControl, 0xA0
.SET SlaveData, 0xA1
	mov $0x11, %al
	out %al, $MasterControl # Starts setup of controllers
	out %al, $SlaveControl

	mov $0x20, %al
	out %al, $MasterData # Master PIC interrupt id
	mov $0x28, %al
	out %al, $SlaveData # Slave PIC interrupt id

	mov $0x04, %al
	out %al, $MasterData # Tells master that it has a slave at IRQ2 (0000 0100)
	mov $0x02, %al
	out %al, $SlaveData # Tells the slave that it's a slave (0000 0010)

	mov $0x01, %al
	out %al, $MasterData # 8086/88 (MCS-80/85) mode
	out %al, $SlaveData

	mov $0x0, %al
	out %al, $MasterData # Sets the masks to 0
	out %al, $SlaveData

.jumpToX64:
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
.SET MAP4M,       0x80
.SET UNKNOWN_BIT, 0x0
.SET PW, PRESENT + WRITEABLE
.SET ATTR, (- KERNEL_VMA + PW)
.SET ATTR_MAP, (PW + MAP4M)
.SET STACK_ATTR, (- KERNEL_VMA + PW + UNKNOWN_BIT)

.macro mapPage from, to
	.int \from + PW + UNKNOWN_BIT, 0
	.if \to-\from
		mapPage "(\from+0x1000)", \to
	.endif
.endm

# Kinda stole this from https://github.com/Bloodmanovski/Trinix/blob/master/KernelLand/Kernel/Architectures/x86_64/Boot/Boot.s

 .global PML4
PML4:
	.int PDP + ATTR, 0 # Identity map for low 4MB
	.space (255) * 8
	.int PDP_MAP + ATTR, 0
	.space (63) * 8
	.quad 0 #.int PDP_STACK + ATTR, 0 # Kernel stack
	.space (187) * 8

	.quad 0 #.int PML4 + ATTR, 0 # Fractal mapping
	.quad 0
	.quad 0
	.int PDP_HIGH + ATTR, 0 # Map low 4MB to kernel base

PDP:
	.int PD + ATTR, 0
	.space 511 * 8

PDP_MAP:
	.int PD_MAP0 + ATTR, 0
	.int PD_MAP1 + ATTR, 0
	.int PD_MAP2 + ATTR, 0
	.int PD_MAP3 + ATTR, 0
	.space 508 * 8

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
	.int PT_10 + ATTR, 0
	.int PT_11 + ATTR, 0
	.int PT_12 + ATTR, 0
	.int PT_13 + ATTR, 0
	.int PT_14 + ATTR, 0
	.int PT_15 + ATTR, 0
	.int PT_16 + ATTR, 0
	.int PT_17 + ATTR, 0
	.int PT_18 + ATTR, 0
	.int PT_19 + ATTR, 0
	.int PT_20 + ATTR, 0
	.int PT_21 + ATTR, 0
	.int PT_22 + ATTR, 0
	.int PT_23 + ATTR, 0
	.int PT_24 + ATTR, 0
	.int PT_25 + ATTR, 0
	.int PT_26 + ATTR, 0
	.int PT_27 + ATTR, 0
	.int PT_28 + ATTR, 0
	.int PT_29 + ATTR, 0
	.int PT_30 + ATTR, 0
	.int PT_31 + ATTR, 0
	.int PT_32 + ATTR, 0
	.space (512 - 32) * 8

.macro mapPDMap from, to
	.int \from + ATTR_MAP, 0
	.if \to-\from
		mapPDMap "(\from+0x200000)", \to
	.endif
.endm
.macro map4MB offset
	mapPDMap (0x200000 * (0   + \offset)), (0x200000 * (64  + \offset))
	mapPDMap (0x200000 * (65  + \offset)), (0x200000 * (128 + \offset))
	mapPDMap (0x200000 * (129 + \offset)), (0x200000 * (192 + \offset))
	mapPDMap (0x200000 * (193 + \offset)), (0x200000 * (256 + \offset))
	mapPDMap (0x200000 * (257 + \offset)), (0x200000 * (320 + \offset))
	mapPDMap (0x200000 * (321 + \offset)), (0x200000 * (384 + \offset))
	mapPDMap (0x200000 * (385 + \offset)), (0x200000 * (448 + \offset))
	mapPDMap (0x200000 * (449 + \offset)), (0x200000 * (511 + \offset))
.endm

PD_MAP0:
	map4MB 512*0
PD_MAP1:
	map4MB 512*1
PD_MAP2:
	map4MB 512*2
PD_MAP3:
	map4MB 512*3

.macro map2MB offset
	mapPage (0x1000 * (0   + \offset)), (0x1000 * (64  + \offset))
	mapPage (0x1000 * (65  + \offset)), (0x1000 * (128 + \offset))
	mapPage (0x1000 * (129 + \offset)), (0x1000 * (192 + \offset))
	mapPage (0x1000 * (193 + \offset)), (0x1000 * (256 + \offset))
	mapPage (0x1000 * (257 + \offset)), (0x1000 * (320 + \offset))
	mapPage (0x1000 * (321 + \offset)), (0x1000 * (384 + \offset))
	mapPage (0x1000 * (385 + \offset)), (0x1000 * (448 + \offset))
	mapPage (0x1000 * (449 + \offset)), (0x1000 * (511 + \offset))
.endm

PT_1:
	map2MB 512*0
PT_2:
	map2MB 512*1
PT_3:
	map2MB 512*2
PT_4:
	map2MB 512*3
PT_5:
	map2MB 512*4
PT_6:
	map2MB 512*5
PT_7:
	map2MB 512*6
PT_8:
	map2MB 512*7

PT_9:
	map2MB 512*8
PT_10:
	map2MB 512*9
PT_11:
	map2MB 512*10
PT_12:
	map2MB 512*11
PT_13:
	map2MB 512*12
PT_14:
	map2MB 512*13
PT_15:
	map2MB 512*14
PT_16:
	map2MB 512*15

PT_17:
	map2MB 512*16
PT_18:
	map2MB 512*17
PT_19:
	map2MB 512*18
PT_20:
	map2MB 512*19
PT_21:
	map2MB 512*20
PT_22:
	map2MB 512*21
PT_23:
	map2MB 512*22
PT_24:
	map2MB 512*23

PT_25:
	map2MB 512*24
PT_26:
	map2MB 512*25
PT_27:
	map2MB 512*26
PT_28:
	map2MB 512*27
PT_29:
	map2MB 512*28
PT_30:
	map2MB 512*29
PT_31:
	map2MB 512*30
PT_32:
	map2MB 512*31




.section .padata
.global KERNEL_STACK
.global KERNEL_STACK_START
KERNEL_STACK:
	.space 0x1000 * (KERNEL_STACK_SIZE - 1)
KERNEL_STACK_START:


# TODO: Define name the constants
.global gdt
.align 16
gdt:
	.quad 0

	gdtCode64:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xA09A00
	gdtData64:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xA09200

	gdtCode32:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xC09A00
	gdtData32:
		.int 0x0000FFFF
		.int 0x000F0000 + 0xC09200

gdtPointer:
	.word . - gdt - 1
	.int gdt - KERNEL_VMA, 0
