/**
 * The second boot code that gets control from init32.S and call the D main function.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
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
