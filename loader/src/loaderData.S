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
	.space 64
