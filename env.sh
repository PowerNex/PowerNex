function c() {
		rm -rf .wild-cache PowerNex.iso Disk/boot/PowerNex.{krl,dsk} Initrd/Binary Userspace/lib {Kernel,Userspace/{Init,libRT,libPowerNex,Shell,Cat,HelloWorld}}/obj/
}
function v() {c && ./build}
function b() {v && qemu-system-x86_64 -cdrom PowerNex.iso -m 2048 -monitor stdio -serial file:COM1.log -no-reboot}
function a() {addr2line -e Disk/boot/PowerNex.krl $1}
