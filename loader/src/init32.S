.macro VERSION
	.ascii "PowerD v0.0.0-ALPHA "
.endm

.set MULTIBOOT2_HEADER_MAGIC, 0xe85250d6
.set MULTIBOOT_ARCHITECTURE_I386, 0
.set MULTIBOOT_HEADER_TAG_END, 0

.section .multiboot
.align 8
multiboot2Header:
	.int MULTIBOOT2_HEADER_MAGIC
	.int MULTIBOOT_ARCHITECTURE_I386
	.int (multiboot2HeaderEnd - multiboot2Header)
	.int -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT_ARCHITECTURE_I386 + (multiboot2HeaderEnd - multiboot2Header))

	.short MULTIBOOT_HEADER_TAG_END
	.short 0
	.int 0
multiboot2HeaderEnd:

.text
.code32

.global loaderData_start
.global loaderData_end

.global pml4
.global pml3_0
.global pml2_0_0

.global gdt
.global gdtPointer
.global multibootPointer

# External files
.global start64

.global start
start:
	xchg %bx, %bx

	cli
	mov $stack, %esp
	push %eax # Magic
	push %ebx # Struct

.zeroLoaderData:
	mov $loaderData_end, %eax
	sub $loaderData_start, %eax
	mov $4, %edi
	div %edi # 4bytes / loop
	mov %eax, %ecx

	mov $loaderData_start, %edi
	xor %eax, %eax
	repnz
	stosl

.init:
	pop %ebx # Struct
	pop %eax # Magic

	cmp $0x36d76289, %eax
	jne invalidMagic

	mov %ebx, multibootPointer

.helloWorld:
	mov $0x0E, %ah # Color
	mov $0xB8000, %edi # Pos
	mov $welcomeMsg, %esi
	call writeString

.longModeCheck:
	# Check to check if we can check if x64 is supported
	mov $0x80000000, %eax
	cpuid
	cmp $0x80000001, %eax
		jb notX64Capable

	# Check so that x64 is supported
	mov $0x80000001, %eax
	cpuid
	test $(1 << 29), %edx
		jz notX64Capable

.setupGDT:
	movl $0x0000FFFF, (gdt + 8 * 1) # gdtCode64
	movl $0x00AF9A00, (gdt + 8 * 1 + 4)
	movl $0x0000FFFF, (gdt + 8 * 2) # gdtData64
	movl $0x00AF9200, (gdt + 8 * 2 + 4)

	mov $gdtPointer, %esi
	movw $(3 * 8 - 1), (%esi)

	movl $gdt, (gdtPointer + 2)
	movl $0, (gdtPointer + 2 + 4)

.setupPaging:
	mov $pml4, %eax
	mov %eax, %cr3

	movl $(pml3_0 + 0x3), pml4 + 0 * 8
	movl $(pml2_0_0 + 0x3), pml3_0 + 0 * 8
	movl $(pml1_0_0_X + 0x3), pml2_0_0 + 0 * 8

	movl $(pml2_0_0 + 0 * 8), %edi
	movl $(pml1_0_0_X + 0x3), %esi
	movl $8, %ecx
	1:
		movl %esi, (%edi)
		addl $0x1000, %esi
		addl $0x8, %edi
		loop 1b

	# Skip nullpage
	movl $(pml1_0_0_X + 8), %edi
	movl $(0x1000 + 0x003), %esi
	movl $(8 * 512 - 1), %ecx
	1:
		movl %esi, (%edi)
		addl $0x1000, %esi
		addl $0x8, %edi
		loop 1b

	movl $(pml4 + 0x3), pml4 + 509 * 8

.enablePaging:
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

.jumpMain:
	lgdt (gdtPointer)
	ljmp $0x8, $start64

.end:
	hlt
	jmp .end

invalidMagic:
	mov $0x4E, %ah # Color
	mov $0xB8000, %edi # Pos
	mov $invalidMagicMsg, %esi
	call writeString
	jmp .end

notX64Capable:
	mov $0x4A, %ah
	mov $0xB8000, %edi
	mov $x64NotSupported_msg, %esi
	call writeString
	jmp .end

writeString:
	lodsb
	test %al, %al
		jz .hidecursor
	stosw
	jmp writeString

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
	ret

.section .rodata
welcomeMsg:
	VERSION
	.ascii "- https://powernexos.org"
	.byte 0

invalidMagicMsg:
	.ascii "                                                                                "
	.ascii "                   _____                       _   _                            "
	.ascii "                  |  __ \\                     | \\ | |                           "
	.ascii "                  | |__) |____      _____ _ __|  \\| | _____  __                 "
	.ascii "                  |  ___/ _ \\ \\ /\\ / / _ \\ '__| . ` |/ _ \\ \\/ /                 "
	.ascii "                  | |  | (_) \\ V  V /  __/ |  | |\\  |  __/>  <                  "
	.ascii "                  |_|   \\___/ \\_/\\_/ \\___|_|  |_| \\_|\\___/_/\\_\\                 "
	.ascii "                              "
	VERSION
	.ascii "                              "
	.ascii "                                                                                "
	.ascii "          *The bootloader provided an invalid multiboot2 magic number*          "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "               Please boot PowerNex using a multiboot2 bootloader               "
	.ascii "               Examples of bootloaders that are supported:                      "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  * GRUB2      - gnu.org/software/grub                          "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  If you believe that you saw this message                      "
	.ascii "                  because of an error.                                          "
	.ascii "                  Please report it to: powernexos.org                           "
	.ascii "                                   or: powernex@vild.io                         "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.byte 0

x64NotSupported_msg:
	.ascii "                                                                                "
	.ascii "                   _____                       _   _                            "
	.ascii "                  |  __ \\                     | \\ | |                           "
	.ascii "                  | |__) |____      _____ _ __|  \\| | _____  __                 "
	.ascii "                  |  ___/ _ \\ \\ /\\ / / _ \\ '__| . ` |/ _ \\ \\/ /                 "
	.ascii "                  | |  | (_) \\ V  V /  __/ |  | |\\  |  __/>  <                  "
	.ascii "                  |_|   \\___/ \\_/\\_/ \\___|_|  |_| \\_|\\___/_/\\_\\                 "
	.ascii "                              "
	VERSION
	.ascii "                              "
	.ascii "                                                                                "
	.ascii "                   *The current setup can not run 64-bit code*                  "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  Please run PowerNex in a VM which supports it                 "
	.ascii "                  Examples of VM that are supported:                            "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  * QEMU       - qemu.org                                       "
	.ascii "                  * VirtualBox - virtualbox.org                                 "
	.ascii "                                                                                "
	.ascii "                                                                                "
	.ascii "                  If you believe that you saw this message                      "
	.ascii "                  because of an error.                                          "
	.ascii "                  Please report it to: powernexos.org                           "
	.ascii "                                   or: powernex@vild.io                         "
	.ascii "                                                                                "
	.byte 0


.bss
.global stack_end
.global stack
stack_end:
	.space 0x1000
stack:
