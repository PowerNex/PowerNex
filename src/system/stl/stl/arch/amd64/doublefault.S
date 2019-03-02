/**
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */

.text
.code64

.global onDoubleFault
.type onDoubleFault, %function
onDoubleFault:
	movb $'D', (0xb8000)
	movb $'F', (0xb8002)
	mov $0xE9, %dx
	mov $'#', %al
	outb %al, %dx
	outb %al, %dx
	outb %al, %dx
	outb %al, %dx
	outb %al, %dx
	outb %al, %dx
	outb %al, %dx

	mov $onDoubleFaultStr, %rsi
	call e9Write
.hlt:
	hlt
	jmp .hlt
.size onDoubleFault, .-onDoubleFault

.global e9Write
.type e9Write, %function
e9Write: // str = %rsi
	mov $0x4A, %ah
	mov $0xB8000, %edi
	mov $0xE9, %dx
	1:
		lodsb
		test %al, %al
			jz 2f
		outb %al, %dx
		stosw
		jmp 1b
	2:
		ret
.size e9Write, .-e9Write

.section .rodata
.global onDoubleFaultStr
onDoubleFaultStr:
	.asciz "Currently in onDoubleFault"
