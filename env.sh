function initCC() {
	if [ ! -f build/cc/versionInfo ]; then
		mkdir build
		./toolchainManager.d
	fi
}
alias c="rm -rf build/objs powernex.iso && echo \"Clean successful\" || echo \"Clean failed\""
alias v="c; initCC; rdmd build.d"
alias b="v && qemu-system-x86_64 -cdrom powernex.iso -m 512 -monitor stdio -smp 4 -debugcon file:COM1.log -enable-kvm"
alias bd="v && qemu-system-x86_64 -cdrom powernex.iso -m 512 -monitor stdio -smp 4 -debugcon file:COM1.log -d int,guest_errors -D qemu_debug.log"
function a() { addr2line -e build/objs/PowerNex/powernex.krl ${1/_/}; }
function al() { addr2line -e build/objs/PowerD/powerd.ldr ${1/_/}; }
alias log="rdmd log.d COM1.log"
