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

.global cpuInstallCR3
.type cpuInstallCR3, %function
cpuInstallCR3:
	mov %RDI, %CR3
	ret
.size cpuInstallCR3, .-cpuInstallCR3

.global cpuRetCR2
.type cpuRetCR2, %function
cpuRetCR2:
	mov %CR2, %RAX
	ret
.size cpuRetCR2, .-cpuRetCR2

.global cpuFlushPage
.type cpuFlushPage, %function
cpuFlushPage:
	invlpg (%rdi)
	ret
.size cpuFlushPage, .-cpuFlushPage
