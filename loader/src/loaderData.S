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
.global pml1_0_0_X
pml1_0_0_X:
	.space 8 * 0x1000

.global gdt
gdt:
	.space 0x1000
.global gdtPointer
gdtPointer:
	.space 16
.global multibootPointer
multibootPointer:
	.space 8
