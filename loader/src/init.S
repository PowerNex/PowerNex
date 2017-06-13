.set MULTIBOOT2_HEADER_MAGIC, 0xe85250d6
.set MULTIBOOT_ARCHITECTURE_I386, 0
.set MULTIBOOT_HEADER_TAG_END, 0

.section multiboot
.align 8
multiboot2_header:
	.int MULTIBOOT2_HEADER_MAGIC
	.int MULTIBOOT_ARCHITECTURE_I386
	.int (multiboot2_header_end - multiboot2_header)
	.int -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT_ARCHITECTURE_I386 + (multiboot2_header_end - multiboot2_header))

	.short MULTIBOOT_HEADER_TAG_END
	.short 0
	.int 0
multiboot2_header_end:

.text
.code32

.global start
start:
	cli

	mov $0x0E, %ah
	mov $0xB8000, %edi
	mov $welcome_msg, %esi
	call writeString

.end:
	hlt
	jmp .end

writeString:
	lodsb
	test %al, %al
		jz .hidecursor
	stosw
	jmp writeString

.hidecursor:
	mov $0x0F, %al
	mov $0x3D4, %dx
	out %al, %dx

	mov $0xFF, %al
	mov $0x3D5, %dx
	out %al, %dx

	mov $0x0E, %al
	mov $0x3D4, %dx
	out %al, %dx

	mov $0xFF, %al
	mov $0x3D5, %dx
	out %al, %dx
	ret

.section .data

.section .rodata
welcome_msg:
	.ascii "PowerD v0.0.0-ALPHA - https://powernexos.org"
	.byte 0
