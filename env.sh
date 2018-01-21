function initCC() {
	if [ ! -f build/cc/versionInfo ]; then
		./toolchainManager.d
	fi
}
function c() { rm -rf build/objs powernex.iso && echo "Clean successful" || echo "Clean failed"; }
function v() { c; initCC; rdmd build.d; }
function b() { v && qemu-system-x86_64 -cdrom powernex.iso -m 512 -monitor stdio -smp 4 -serial file:COM1.log -enable-kvm 2>/dev/null; }
function bd() { v && qemu-system-x86_64 -cdrom powernex.iso -m 512 -monitor stdio -smp 4 -serial file:COM1.log -d int,guest_errors -D qemu_debug.log 2>/dev/null; }
function a() { addr2line -e build/objs/PowerNex/disk/boot/powernex.krl $1; }
function al() { addr2line -e build/objs/PowerD/disk/boot/powerd.ldr $1; }
function log() { tail -f COM1.log -n64 | dtools-ddemangle | sed -e "s/\(.*[\&].*\)/\o033[0;33m\1\o033[0m/g" -e "s/\(.*[\+].*\)/\o033[1;32m\1\o033[0m/g" -e "s/\(.*[\*].*\)/\o033[1;36m\1\o033[0m/g" -e "s/\(.*[\#].*\)/\o033[1;33m\1\o033[0m/g" -e "s/\(.*[\-].*\)/\o033[0;31m\1\o033[0m/g" -e "s/\(.*[\!].*\)/\o033[1;31m\1\o033[0m/g"; }
