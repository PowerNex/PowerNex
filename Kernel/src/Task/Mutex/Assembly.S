.text
.code64

.global spinlock_lock
spinlock_lock:
.retry:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz .retry
	ret

.global spinlock_trylock
spinlock_trylock:
	mov $1, %RBX;
	lock cmpxchgq %RBX, (%RDI)
	jnz .r
	mov $1, %RAX
.r:
	ret

.global spinlock_unlock
spinlock_unlock:
	movq $1, (%RDI)
	ret
