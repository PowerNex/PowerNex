function initPowerNex() {
	if [ ! -f build.ninja ]; then
		dub fetch reggae
		dub run reggae -- -b ninja .
	fi
}
function c() { rm -rf objs powernex.iso && echo "Clean successful" || echo "Clean failed"; }
function v() { initPowerNex && ninja; }
function b() { v && qemu-system-x86_64 -cdrom powernex.iso -m 256 -monitor stdio -smp 4 -serial file:COM1.log 2>/dev/null; }
function a() { addr2line -e objs/powernex.iso.objs/disk/boot/powernex.krl $1; }
function al() { addr2line -e objs/powernex.iso.objs/disk/boot/powerd.ldr $1; }
function log() { tail -f COM1.log -n64 | dtools-ddemangle| sed -e "s/\(.*[\&].*\)/\o033[0;33m\1\o033[0m/g" -e "s/\(.*[\+].*\)/\o033[1;32m\1\o033[0m/g" -e "s/\(.*[\*].*\)/\o033[1;36m\1\o033[0m/g" -e "s/\(.*[\#].*\)/\o033[1;33m\1\o033[0m/g" -e "s/\(.*[\-].*\)/\o033[0;31m\1\o033[0m/g" -e "s/\(.*[\!].*\)/\o033[1;31m\1\o033[0m/g"; }
