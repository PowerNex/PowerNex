PowerNex
========

PowerNex is a kernel written in the [D Programming Language](http://dlang.org/).
The goal is to have a whole OS written in D, where PowerNex powers the core.

The name PowerNex comes from the words `power` and `next`. A kernel to power the
next generation of hardware.

Building
--------
It requires a crosscompiler, see link below for download.
It uses my build system called [Wild](https://github.com/Vild/Wild)
It expects the wild binary to be located in the root directory of PowerNex, then
you just need to run `./build` to build.

[Prebuild toolchain (wild and compilers) for (Arch)Linux x64](https://mega.nz/#!cx913RZZ!i3lHemFSPRT5kgdbGjS9YgXLKx0bV84Jg50cOYOdxUg)

One tip is to run `source env.sh`, this adds shortcuts for building and running.
	`b` compiles and runs PowerNex in qemu, `v` just builds PowerNex.


System requirements
-------------------
- A 64bit processor
- At least 32 MiB of ram

*Recommended & Supported Virtual Machines*
- QEMU
- VirtualBox

Thanks to
---------
* Adam D. Ruppe - For his [minimal.zip](http://arsdnet.net/dcode/minimal.zip),
	which contains a bare bone minimal d runtime. Which this kernel is based on.
* Bloodmanovski - For his D Kernel [Trinix](https://github.com/Bloodmanovski/Trinix)
	His files for booting x64 really helped me alot.

Authors
-------
Dan Printzell

License
-------
Mozilla Public License, version 2.0
