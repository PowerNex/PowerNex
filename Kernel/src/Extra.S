.text
.code64

.global CPU_refresh_iretq
.type CPU_refresh_iretq, %function
CPU_refresh_iretq:
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
.size CPU_refresh_iretq, .-CPU_refresh_iretq

.global CPU_install_cr3
.type CPU_install_cr3, %function
CPU_install_cr3:
	mov %RDI, %CR3
	ret
.size CPU_install_cr3, .-CPU_install_cr3

.global CPU_ret_cr2
.type CPU_ret_cr2, %function
CPU_ret_cr2:
	mov %CR2, %RAX
	ret
.size CPU_ret_cr2, .-CPU_ret_cr2

.global CPU_flushPage
.type CPU_flushPage, %function
CPU_flushPage:
	invlpg (%rdi)
	ret
.size CPU_flushPage, .-CPU_flushPage
