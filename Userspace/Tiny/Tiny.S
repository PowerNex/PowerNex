.text
.code64
.global _start
.type _start, %function
_start:
	mov $0, %rax
	mov $42, %ebx
	int $0x80
.size _start, .-_start
