# micro-ecc

This directory contains the micro-ecc C source used by Dexcom G7 Primary authentication.

Upstream project: https://github.com/kmackay/micro-ecc

Pinned revision: `541b3a78026420a3e369c4c9281c396b5e531113`

License: BSD 2-Clause. See `LICENSE.txt` in this directory.

The files are intentionally not separate Xcode Compile Sources entries. `DexcomG7ECC.c` includes
the implementation inside one configured translation unit so that only P-256 is enabled and the
low-level VLI operations required by J-PAKE are available. Adding `uECC.c` separately to the target
would compile duplicate symbols and would bypass those configuration flags.
