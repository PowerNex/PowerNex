function v() {rm -rf powernex.krl kernel/obj/ .wild-cache && ./build}
function b() {rm -rf powernex.krl kernel/obj/ .wild-cache && ./build && qemu-system-x86_64 -cdrom powernex.iso -m 2048 -monitor stdio -serial file:com1.log -no-reboot}
function n() {rm -rf powernex.krl kernel/obj/ .wild-cache bochsout.txt && ./build && bochs -f bochsrc.txt}
