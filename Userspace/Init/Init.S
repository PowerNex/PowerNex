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
	mov HelloWorld, %rdi
	call printcstr

	movq $42, (ExitValue)
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

.section .rodata, "aS"
HelloWorld: .ascii "Hello World\0"

.data
ExitValue: .quad 0
