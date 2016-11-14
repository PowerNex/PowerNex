.text
.code64

.global mutex_spinlock
mutex_spinlock:
1:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz 1b
	ret

.global mutex_trylock
mutex_trylock:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz 1f
	mov $1, %RAX
1:
	ret

.global mutex_unlock
mutex_unlock:
	movq $1, (%RDI)
	ret
