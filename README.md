# x86 boot

This is the first lab of the COS773 course. It is a simple boot loader that loads a kernel from disk
(which is just a simple program that prints a message to the screen) and executes it.

## Building

You must have both `i386elfgcc` and `nasm` installed. After that, just run the `run.sh` script.

## Executing

You can run the boot loader with `qemu` by doing:

```
qemu-system-x86_64 -drive format=raw,file=bin/OS.bin,index=0,if=floppy,  -m 128M
```

All the binaries are already in the `bin` folder, if you don't want to build them yourself.
