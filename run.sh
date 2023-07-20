#!/bin/bash

export PATH=$PATH:/usr/local/i386elfgcc/bin

# Cleanup and re-create bin directory
rm -rf bin
mkdir -p bin

# Function for running commands and raising errors if they fail
run() {
    echo "Running: $@"
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Error with $1" >&2
        exit $status
    fi
    return $status
}

# Compile bootloader
echo "Compiling bootloader..."
run nasm -f bin boot.S -o bin/boot.bin

# Compile kernel entry for the cpp code
echo "Compiling kernel entry..."
run nasm -f elf kernel.S -o bin/kernel_asm.o

# Compile kernel cpp code
echo "Compiling kernel cpp code..."
run i386-elf-gcc -ffreestanding -m32 -g -c kernel.cpp -o bin/kernel.o

# Compiling disk filler
echo "Compiling disk zeroes-filler..."
run nasm -f bin zeroes.S -o bin/zeroes.bin

# Linking kernel entry and cpp code
echo "Linking kernel entry and cpp code..."
run i386-elf-ld -o bin/full_kernel.bin -Ttext 0x1000 bin/kernel_asm.o bin/kernel.o --oformat binary

# Chain bootloader, kernel and disk filler
echo "Chaining bootloader, kernel and disk filler..."
cat bin/boot.bin bin/full_kernel.bin bin/zeroes.bin  > bin/OS.bin

# Run with qemu
echo "Running with qemu..."
run qemu-system-x86_64 -drive format=raw,file=bin/OS.bin,index=0,if=floppy,  -m 128M