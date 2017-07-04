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

