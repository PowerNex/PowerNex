.text
.code64
.global _start
.type _start, %function
_start:
	call main
	mov %rax, %rdi
	jmp exit
.size _start, .-_start


.global main
.type main, %function
main:
	lea HelloWorld, %rdi
	call printcstr

	//lea TryFork, %rdi
	//call printcstr

	//currently not working (problem with Heap?)
	//see Data/ELF.d:357
	//see Task/Scheduler.d:177
	//call fork

	//lea ForkSuccess, %rdi
	//call printcstr

	movq $0x42, (ExitValue)
	movq (ExitValue), %rax
	ret
.size main, .-main

.global exit
.type exit, %function
exit: // Arg: rdi= exit code
	mov $0, %rax
	int $0x80
	hlt
	jmp exit
.size exit, .-exit

.global printcstr
.type printcstr, %function
printcstr: // Arg: rdi= string ptr
	mov $16, %rax
	int $0x80
	ret
.size printcstr, .-printcstr

.global fork
.type fork, %function
fork:
	mov $2, %rax
	int $0x80
	ret
.size fork, .-fork

.section .rodata, "aS"
HelloWorld: .ascii "Hello World from Userspace!\0"
TryFork: .ascii "Trying to fork!\0"
ForkSuccess: .ascii "FORK WORKED!\0"

.data
ExitValue: .quad 0
