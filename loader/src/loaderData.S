/**
 * Contains all the data that will be passed to the kernel.
 * This data will be a the ".loaderData" section, and thus can't be created inside the D code.
 * This can be moved to D code when $(LINK https://issues.dlang.org/show_bug.cgi?id=16300) is fixed.
 *
 * Copyright: © 2015-2017, Dan Printzell
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License Version 2.0)
 *  (See accompanying file LICENSE)
 * Authors: $(LINK2 https://vild.io/, Dan Printzell)
 */
.section .loaderData, "aw", @nobits

.global pml4
pml4:
	.space 0x1000
.global pml3_0
pml3_0:
	.space 0x1000
.global pml2_0_0
pml2_0_0:
	.space 0x1000
.global pml1_0_0_0
pml1_0_0_0:
	.space 0x1000

.global gdtDescriptors
gdtDescriptors:
	.space 0x1000

.global gdtBase
gdtBase:
	.space 16

.global multibootPointer
multibootPointer:
	.space 8

.global powerDHeader
powerDHeader:
	.space 32

.global powerDACPI
powerDACPI:
	.space 64
