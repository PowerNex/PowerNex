function v() {rm -rf powernex.krl kernel/obj/ .wild-cache && ./build}
function b() {rm -rf powernex.krl kernel/obj/ .wild-cache && ./build && qemu-system-x86_64 -cdrom powernex.iso -m 512 -monitor stdio}
function n() {rm -rf powernex.krl kernel/obj/ .wild-cache bochsout.txt && ./build && bochs -f bochsrc.txt}
