/**
 * Helper functions for the spinlock, that can't be written in D.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
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
