.text
.code64
.SET USER_CS, 0x18 | 0x3
.SET KERNEL_STACK, 632//Process.image.offsetof + ImageInformation.kernelStack.offsetof

.global _D6System14SyscallHandler14SyscallHandler16onSyscallHandlerFPS4Data8Register9RegistersZv
.global currentProcess

.global onSyscall
.type onSyscall, %function
onSyscall:
	mov %rsp, userStack
	movq currentProcess, %rsp
	movq KERNEL_STACK(%rsp), %rsp
	push (userStack)

	push $(USER_CS + 8) // SS
	push (userStack) // RSP
	push %r11 // Flags
	push $(USER_CS) // CS
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
	call _D6System14SyscallHandler14SyscallHandler16onSyscallHandlerFPS4Data8Register9RegistersZv
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
