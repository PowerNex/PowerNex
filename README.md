# **Please note that the current code is undergoing a major overhaul!**

<p align="center">
<img alt="PowerNex Logo" width="346" src="https://github.com/PowerNex/PowerNex/raw/master/data/logo.png">
</p>


**PowerNex** is a OS written in the [D Programming Language](https://dlang.org).
The goal is to have a whole OS written in D, where the PowerNex kernel powers the core.

The name PowerNex comes from the words `power` and `next`. A kernel to power the
next generation of hardware.

## System requirements ##
- A 64bit processor
- At least 512 MiB of ram (less will probably work)

## Build Instructions ##
It requires a crosscompiler, which can be aquired by running `./toolchainManager.d`.
PowerNex is using a custom build system. For its code look inside `build.d`, `src/buildlib.d`, and `src/*/project.d`.

To use the following shortcuts run `source env.sh` in your shell.
- **`c`** - Removes the build files
- **`v`** - Compiles PowerNex
- **`b`** - Compiles and runs PowerNex in qemu
- **`bd`** - Compiles and runs PowerNex in qemu, with debug logs to qemu_debug.log
- **`a`** - Runs *addr2line* on the kernel
- **`al`** - Runs *addr2line* on the loader
- **`log`** - Runs *tail* on the COM1.log, and demangles and inserts colors for the entries.

## How to contribute ##
- Make issues
- Make PRs
- Comment on issues
  - Example help with [#30 Mascot](https://github.com/PowerNex/PowerNex/issues/30)
- Donate
  - One time donations (to Wild): [https://www.paypal.me/Vild](https://www.paypal.me/Vild)

## Thanks to ##
- Adam D. Ruppe - For his [minimal.zip](http://arsdnet.net/dcode/minimal.zip), which contains a bare bone minimal d runtime.
- Bloodmanovski - For his D Kernel [Trinix](https://github.com/Bloodmanovski/Trinix), His files for booting x64 really helped me a lot in the beginning.
- Lukas "zrho" Heidemann - For his [Hydrogen](https://github.com/zrho/Hydrogen) project. It really inspired and help me to make PowerD, the intermediate bootloader.

## Community ##
- #powernex on freenode
- https://discordapp.com/invite/bMZk9Q4

## License ##
Mozilla Public License, version 2.0