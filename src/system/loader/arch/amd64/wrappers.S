/**
 * Here we have a couple of helper functions that can't be written in D.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */

.text
.code64

.global cpuRefreshIREQ
.type cpuRefreshIREQ, %function
cpuRefreshIREQ:
	mov $0x10, %RAX
	mov %AX, %DS
	mov %AX, %ES
	mov %AX, %SS

	mov %RSP, %RDX
	push %RAX
	push %RDX
	pushfq
	push $0x08

	mov $1f, %RAX
	push %RAX
	iretq

	1:
		ret
.size cpuRefreshIREQ, .-cpuRefreshIREQ

.global cpuFlushPage
.type cpuFlushPage, %function
cpuFlushPage:
	invlpg (%rdi)
	ret
.size cpuFlushPage, .-cpuFlushPage

.global cpuRetCR0
.type cpuRetCR0, %function
cpuRetCR0:
	mov %CR0, %RAX
	ret
.size cpuRetCR0, .-cpuRetCR0

.global cpuRetCR2
.type cpuRetCR2, %function
cpuRetCR2:
	mov %CR2, %RAX
	ret
.size cpuRetCR2, .-cpuRetCR2

.global cpuRetCR3
.type cpuRetCR3, %function
cpuRetCR3:
	mov %CR3, %RAX
	ret
.size cpuRetCR3, .-cpuRetCR3

.global cpuRetCR4
.type cpuRetCR4, %function
cpuRetCR4:
	mov %CR4, %RAX
	ret
.size cpuRetCR4, .-cpuRetCR4

.global LAPIC_dummyTimer
.type LAPIC_dummyTimer, %function
LAPIC_dummyTimer:
.SET APIC_EOI, 0x0B0
	movq $LAPIC_address, %rax
	movl $0, APIC_EOI(%rax)
	iretq
.size LAPIC_dummyTimer, .-LAPIC_dummyTimer

.global LAPIC_dummyTimerx2
.type LAPIC_dummyTimerx2, %function
LAPIC_dummyTimerx2:
.SET APIC_MSR_BASE, 0x800
.SET APIC_MSR_EOI, 0x0B
	mov $0, %eax
	mov $0, %edx
	mov $(APIC_MSR_BASE + APIC_MSR_EOI), %ecx
	wrmsr
	iretq
.size LAPIC_dummyTimerx2, .-LAPIC_dummyTimerx2

.global LAPIC_spuriousTimer
.type LAPIC_spuriousTimer, %function
LAPIC_spuriousTimer:
	iretq
.size LAPIC_spuriousTimer, .-LAPIC_spuriousTimer

.bss
.global LAPIC_address
LAPIC_address:
	.space 8
