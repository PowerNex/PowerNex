/**
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */

.text
.code64

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
