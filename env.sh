function v() {rm -rf Kernel/obj/ .wild-cache && ./build}
function b() {rm -rf Kernel/obj/ .wild-cache && ./build && qemu-system-x86_64 -cdrom PowerNex.iso -m 2048 -monitor stdio -serial file:COM1.log -no-reboot}
function n() {rm -rf Kernel/obj/ .wild-cache bochsout.txt && ./build && bochs -f bochsrc.txt}
function a() {addr2line -e Disk/boot/PowerNex.krl $1}