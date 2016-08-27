.text
.code64

.global mutex_spinlock
mutex_spinlock:
.retry:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz .retry
	ret

.global mutex_trylock
mutex_trylock:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz .r
	mov $1, %RAX
.r:
	ret

.global mutex_unlock
mutex_unlock:
	movq $1, (%RDI)
	ret
