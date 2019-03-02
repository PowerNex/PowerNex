/**
 * The early boot code that get control from GRUB and sets up 64bit to be able to call the second part of the boot code.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */

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
	.int 8
multiboot2HeaderEnd:

.section .initCode, "ax"
.align 16
.code32

# External files
.global start64

.global start
.type start, %function
start:
	xchg %bx, %bx
	jmp boot32BSP
.size start, .-start

.type boot32BSP, %function
boot32BSP:
	cli
	mov $stack, %esp

	cmp $0x36d76289, %eax
	jne invalidMagic
	mov %ebx, multibootPointer

	call helloWorld
	call longModeCheck
	call remapIRQ
	call setupPaging
	call enablePagingAndLongMode
	call jumpMainBSP
.size boot32BSP, .-boot32BSP

.global boot32AP
.type boot32AP, %function
boot32AP:
	mov $apStack, %esp

	mov $0xA0, %ah # Color
	mov $0xB8000, %edi # Pos
	mov $welcomeAPMsg, %esi
	call writeString

	call longModeCheck
	call enablePagingAndLongMode
	call jumpMainAP
.size boot32AP, .-boot32AP

.type helloWorld, %function
helloWorld:
	mov $0x0E, %ah # Color
	mov $0xB8000, %edi # Pos
	mov $welcomeMsg, %esi
	call writeString

	ret
.size helloWorld, .-helloWorld

.type longModeCheck, %function
longModeCheck:
	# Check to check if we can check if x64 is supported
	mov $0x80000000, %eax
	cpuid
	mov $'1', %esi
	cmp $0x80000001, %eax
		jb notX64Capable # if it is less

	# Check so that x64 is supported
	mov $0x80000001, %eax
	cpuid
	mov $'2', %esi
	test $(1 << 29), %edx
		jz notX64Capable

	# Check so that SSE3 is supported
	mov $0x1, %eax
	cpuid
	mov $'3', %esi
	test $(1 << 0), %ecx
		jz notX64Capable
	ret
.size longModeCheck, .-longModeCheck

.type remapIRQ, %function
remapIRQ:
	.SET MasterControl, 0x20
	.SET MasterData, 0x21
	.SET SlaveControl, 0xA0
	.SET SlaveData, 0xA1
	.SET IRQBase, 0x20
	mov $0x11, %al
	out %al, $MasterControl # Starts setup of controllers
	out %al, $SlaveControl

	mov $IRQBase, %al
	out %al, $MasterData # Master PIC interrupt id
	mov $(IRQBase + 8), %al
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
	ret
.size remapIRQ, .-remapIRQ

.type setupPaging, %function
setupPaging:
	movl $(pml3_0 + 0x3), pml4 + 0 * 8
	movl $(pml2_0_0 + 0x3), pml3_0 + 0 * 8
	movl $(pml1_0_0_0 + 0x3), pml2_0_0 + 0 * 8

	# Skip nullpage
	movl $(pml1_0_0_0 + 8), %edi
	movl $(0x1000 + 0x003), %esi
	movl $(512 - 1), %ecx
	1:
		movl %esi, (%edi)
		addl $0x1000, %esi
		addl $0x8, %edi
		loop 1b

	# 2MiB rest of pages
	movl $(pml2_0_0 + 8), %edi
	movl $(0x200000 + 0x83), %esi
	movl $511, %ecx
	1:
		movl %esi, (%edi)
		add $0x200000, %esi
		add $0x8, %edi
		loop 1b

	movl $(pml4 + 0x3), pml4 + 509 * 8

	movl $(pml3_510 + 0x3), pml4 + 510 * 8
	movl $(pml2_510_0 + 0x3), pml3_510 + 0 * 8
	movl $(pml1_510_0_0 + 0x3), pml2_510_0 + 0 * 8
	ret
.size setupPaging, .-setupPaging

.type enablePagingAndLongMode, %function
enablePagingAndLongMode:
	mov $pml4, %eax
	mov %eax, %cr3

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
	ret
.size enablePagingAndLongMode, .-enablePagingAndLongMode

.type jumpMainBSP, %function
jumpMainBSP:
	lgdt gdtBase
	ljmp $0x8, $boot64BSP
.size jumpMainBSP, .-jumpMainBSP

.type jumpMainAP, %function
jumpMainAP:
	lgdt gdtBase
	ljmp $0x8, $boot64AP
.size jumpMainAP, .-jumpMainAP

.type halt, %function
halt:
	hlt
	jmp halt
.size halt, .-halt

.type invalidMagic, %function
invalidMagic:
	mov $0x4E, %ah # Color
	mov $0xB8000, %edi # Pos
	mov $invalidMagicMsg, %esi
	call writeString
	jmp halt
.size invalidMagic, .-invalidMagic

.type notX64Capable, %function
notX64Capable:
	mov $x64NotSupported_msg, %ebx
	mov %esi, %eax
	movb %eax, (%ebx)

	mov $0x4A, %ah
	mov $0xB8000, %edi
	mov %ebx, %esi
	call writeString
	jmp halt
.size notX64Capable, .-notX64Capable

.type writeString, %function
writeString:
	lodsb
	test %al, %al
		jz .hidecursor
	stosw
	jmp writeString
.size writeString, .-writeString

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

welcomeAPMsg:
	.ascii "Hi, I'm a AP"
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

gdtDescriptors:
	.quad 0x0000000000000000
	.quad 0x00AF9A000000FFFF
	.quad 0x00AF92000000FFFF

gdtBase:
	.short (3 * 8 - 1) # limit
	.int gdtDescriptors # base
	.short 0 # padding

.bss
.align 0x1000
.global pml4
pml4:
	.space 0x1000
pml3_0:
	.space 0x1000
pml2_0_0:
	.space 0x1000
pml1_0_0_0:
	.space 0x1000

pml3_510:
	.space 0x1000
pml2_510_0:
	.space 0x1000
pml1_510_0_0:
	.space 0x1000

.global stack_end
.global stack
stack_end:
	.space 0x4000
stack:

apStack_end:
	.space 0x400
apStack:

.global multibootPointer
multibootPointer:
	.space 8
