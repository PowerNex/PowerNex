/**
 * The second boot code that gets control from init32.S and call the D main function.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
.section .initCode, "ax"
.code64

.global main
.global newStackAP
.global mainAP
.global multibootPointer

.global boot64BSP
.type boot64BSP, %function
boot64BSP:
	cli
	mov $0x10, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	mov $0, %rbp

	mov multibootPointer, %edi
	call main

	1:
		hlt
		jmp 1b
.size boot64BSP, .-boot64BSP

.global boot64AP
.type boot64AP, %function
boot64AP:
	cli
	mov $0x10, %ax
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	call newStackAP
	mov %rax, %rsp
	mov $0, %rbp

	call mainAP

	1:
		hlt
		jmp 1b
.size boot64AP, .-boot64AP

.global __dmd_personality_v0
.type __dmd_personality_v0, %function
__dmd_personality_v0:
	hlt
	jmp __dmd_personality_v0
.size __dmd_personality_v0, .-__dmd_personality_v0
