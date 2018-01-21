.text
.code64

.global mutexSpinlock
mutexSpinlock:
1:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz 1b
	ret

.global mutexTrylock
mutexTrylock:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz 1f
	mov $1, %RAX
1:
	ret

.global mutexUnlock
mutexUnlock:
	movq $1, (%RDI)
	ret
