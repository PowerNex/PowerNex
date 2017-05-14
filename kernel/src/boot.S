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
	.int (multiboot2_header_end - multiboot2_header)
	.int -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT_ARCHITECTURE_I386 + (multiboot2_header_end - multiboot2_header))

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
multiboot2_header_end:

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
		jb notx64Capable

	# Check so that x64 is supported
	mov $0x80000001, %eax
	cpuid
	test $(1 << 29), %edx
		jz notx64Capable

setupPaging:
	mov $(PML4 - KERNEL_VMA), %eax
	mov %eax, %cr3

	movl $(PML3_bootOnly - KERNEL_VMA + 0x003), PML4 - KERNEL_VMA + 0 * 8
	movl $(PML2_bootOnly - KERNEL_VMA + 0x003), PML3_bootOnly - KERNEL_VMA + 0 * 8
	movl $(PML1_bootOnly1 - KERNEL_VMA + 0x003), PML2_bootOnly - KERNEL_VMA + 0 * 8
	movl $(PML1_bootOnly2 - KERNEL_VMA + 0x003), PML2_bootOnly - KERNEL_VMA + 1 * 8

	# Skip nullpage
	movl $(PML1_bootOnly1 - KERNEL_VMA + 8), %edi
	movl $(0x1000 + 0x003), %esi
	movl $(512 * 2 - 1), %ecx
	1:
		movl %esi, (%edi)
		addl $0x1000, %esi
		addl $0x8, %edi
		loop 1b

	movl $(PML4 - KERNEL_VMA + 0x003), PML4 - KERNEL_VMA + 509 * 8

# movl $(PML3_special - KERNEL_VMA + 0x003), PML4 - KERNEL_VMA + 510 * 8

	movl $(PML3_kernel - KERNEL_VMA + 0x003), PML4 - KERNEL_VMA + 511 * 8
	movl $(PML2_kernel - KERNEL_VMA + 0x003), PML3_kernel - KERNEL_VMA + 510 * 8


	movl $(PML2_kernel - KERNEL_VMA), %edi
	movl $(PML1_kernel - KERNEL_VMA + 0x003), %esi
	movl $32, %ecx
	1:
		movl %esi, (%edi)
		addl $0x1000, %esi
		addl $0x8, %edi
		loop 1b


	movl $(PML1_kernel - KERNEL_VMA + 8), %edi
	movl $0x1003, %esi
	movl $(1024 * 32 - 1), %ecx
	1:
		movl %esi, (%edi)
		addl $0x1000, %esi
		addl $0x8, %edi
		loop 1b

enablePaging:
	# Enable PAE
	mov %cr4, %eax
	bts $5, %eax # physical address extension
	bts $7, %eax # paging global extensions
	mov %eax, %cr4

	# Set long mode bit in EFER MSR
	mov $0xC0000080, %ecx # Refers to EFER MSR
	rdmsr
	bts $11, %eax # No execute enable
	bts $0, %eax # SYSCALL/SYSRET
	bts $8, %eax # Long mode enable
	wrmsr

	# Enable paging and write protected
	mov %cr0, %eax
	bts $1, %eax # monitor co-processor
	btr $2, %eax # clear coprocessor emulation
	bts $16, %eax # write protect
	bts $31, %eax # paging
	mov %eax, %cr0

	mov %cr4, %eax
	bts $9, %eax # fxsave and fxrstor instructions
	bts $10, %eax # unmasked simd floating point exceptions
	mov %eax, %cr4

remapIRQ:
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

jumpToX64:
	xchgw %bx, %bx
	# Load x64 GDT
	lgdt (gdtPointer - KERNEL_VMA)
	# Jump into x64
	ljmp $0x8, $(start64 - KERNEL_VMA)

notx64Capable:
	mov $0x4A, %ah
	mov $0xB8000, %edi
	mov $(x64NotSupported_msg - KERNEL_VMA), %esi

writeString:
	lodsb
	test %al, %al
		jz hidecursor
	stosw
	jmp writeString

hidecursor:
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

hlt:
	cli
	hlt
	jmp hlt

.section .data
.global multiboot_magic
multiboot_magic:
	.int 0
.global multiboot_ptr
multiboot_ptr:
	.int 0

.section .rodata
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
	.ascii "                                                                                "
	.ascii "                  * QEMU       - qemu.org                                       "
	.ascii "                  * VirtualBox - virtualbox.org                                 "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  If you believe that you should see this                       "
	.ascii "                  message because of an error.                                  "
	.ascii "                  Please report it to: vild.io/powernex                         "
	.ascii "                                   or: powernex@vild.io                         "
	.ascii "                                                                                "
	.byte 0

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
