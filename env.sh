function initPowerNex() {
	if [ ! -f build.ninja ]; then
		dub fetch reggae
		dub run reggae -- -b ninja .
	fi
}
function c() { rm -rf objs powernex.iso && echo "Clean successful" || echo "Clean failed"; }
function v() { initPowerNex && ninja; }
function b() { v && qemu-system-x86_64 -cdrom powernex.iso -m 256 -monitor stdio -smp cpus=1,cores=2,threads=1,maxcpus=2 -serial file:COM1.log 2>/dev/null; }
function a() { addr2line -e objs/powernex.iso.objs/disk/boot/powernex.krl $1; }
function al() { addr2line -e objs/powernex.iso.objs/disk/boot/powerd.ldr $1; }
