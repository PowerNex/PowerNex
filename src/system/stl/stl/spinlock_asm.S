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
	pushfq
	pop %RCX
	bt $9, %RCX
	jc .tryToSet
	sti

	.tryToSet:
		lock bts $0, (%RDI)
			jc .waitForZero

		bt $9, %RCX
		jc 1f
			cli
		jmp 1f

		1:
			ret

	.waitForZero:
		pause
		testl $1, (%RDI)
			jnz .waitForZero

		jmp .tryToSet




.global mutexTrylock
mutexTrylock:
	xor %RAX, %RAX
	lock bts $0, (%RDI)
		jc .return

	inc %RAX
.return:
	ret

.global mutexUnlock
mutexUnlock:
	movl $0, (%RDI)
	ret
