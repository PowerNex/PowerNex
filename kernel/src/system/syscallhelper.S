.text
.code64
.SET userCS, 0x18 | 0x3
.SET kernelStack, 632//Process.image.offsetof + ImageInformation.kernelStack.offsetof

.global _onSyscallHandler
.global _currentProcess // It is of the type SharedPtr!Process, we need to deref it to get the object

.global onSyscall
.type onSyscall, %function
onSyscall:
	mov %rsp, userStack
	movq (_currentProcess), %rsp
	movq kernelStack(%rsp), %rsp
	push (userStack)

	push $(userCS + 8) // SS
	push (userStack) // RSP
	push %r11 // Flags
	push $(userCS) // CS
	push %rcx // RIP

	push $0 // ErrorCode
	push $0x80 // IntNumber

	push %rax
	push %rbx
	push %rcx
	push %rdx
	push %rsi
	push %rdi
	push %rbp
	push %r8
	push %r9
	push %r10
	push %r11
	push %r12
	push %r13
	push %r14
	push %r15

	mov %rsp, %rdi
	call _onSyscallHandler
	jmp returnFromSyscall
.size onSyscall, .-onSyscall

.global returnFromSyscall
.type returnFromSyscall, %function
returnFromSyscall:
	pop %r15
	pop %r14
	pop %r13
	pop %r12
	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rbp
	pop %rdi
	pop %rsi
	pop %rdx
	pop %rcx
	pop %rbx
	pop %rax

	add $(8*7), %rsp

	pop %rsp
	sysretq
.size returnFromSyscall, .-returnFromSyscall
.bss
userStack: .long 1
userRIP: .long 1
