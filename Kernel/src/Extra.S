.text
.code64

.global CPU_refresh_iretq
CPU_refresh_iretq:
	mov $0x10, %RAX
	mov %AX, %DS
	mov %AX, %ES
	mov %AX, %FS
	mov %AX, %GS
	mov %AX, %SS

	mov %RSP, %RDX
	push %RAX
	push %RDX
	pushfq
	push $0x08

	mov $.r, %RAX
	push %RAX
	iretq

	.r:
		ret

.global CPU_install_cr3
CPU_install_cr3:
	mov %RDI, %CR3
	ret

.global CPU_ret_cr2
CPU_ret_cr2:
	mov %CR2, %RAX
	ret
