function v() {rm -rf PowerNex.krl Kernel/obj/ .wild-cache && ./build}
function b() {rm -rf PowerNex.krl Kernel/obj/ .wild-cache && ./build && qemu-system-x86_64 -cdrom PowerNex.iso -m 2048 -monitor stdio -serial file:COM1.log -no-reboot}
function n() {rm -rf PowerNex.krl Kernel/obj/ .wild-cache bochsout.txt && ./build && bochs -f bochsrc.txt}
