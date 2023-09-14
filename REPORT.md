    Universidade Federal do Rio de Janeiro
    Programa de Engenharia de Sistemas e Computação
    COS773 - Engenharia de Sistemas Operacionais - 2023.Q2
    Relatório Lab Boot
    Gabriel Gazola Milan - DRE 123028727

**Obs:** Todo o código referente a esse trabalho está disponível publicamente no GitHub, no repositório [gabriel-milan/x86_boot](https://github.com/gabriel-milan/x86_boot).

### Introdução

O objetivo desse trabalho é implementar um bootloader para a arquitetura x86, que seja capaz de carregar um kernel do disco e executá-lo. O kernel, em si, consiste em um programa que imprime uma mensagem na tela e entra em um loop infinito.

Existem diversos conteúdos na internet que explicam como atingir esse objetivo, além de diversos toy projects no GitHub que implementam bootloaders para a arquitetura x86. A implementação aqui presente foi baseada em diversos desses recursos, mas principalmente na série de vídeos da Daedalus Community, que particularmente achei uma abordagem muito amigável e didática. O link para o primeiro vídeo da série pode ser encontrado [aqui](https://www.youtube.com/watch?v=MwPjvJ9ulSc).

### Implementação

A primeira parte foi entender as restrições e regras do bootloader. O bootloader deve ser um programa de 512 bytes, que será carregado pelo BIOS na memória RAM, a partir do setor 0 do disco. O BIOS então transfere o controle para o bootloader, que deve carregar o kernel para a memória RAM e transferir o controle para ele. Também, os 512 bytes devem terminar com a assinatura `0xAA55`, que é um magic number pré-definido.

Então, o código assembly mais simples possível é o seguinte:

```asm
jmp $

times 510 - ($-$$) db 0
dw 0xAA55
```

Isso é um loop infinito, seguido de 510 bytes de 0 e, por fim, o magic number. Esse código pode ser compilado com o NASM, que é um assembler para a arquitetura x86, e o resultado é um arquivo binário de 512 bytes. Esse arquivo pode ser executado com o QEMU, que é um emulador de máquinas virtuais, e o resultado é um loop infinito, como esperado.

Em seguida, configura-se o offset de memória para 0x7c00, que é o endereço onde o BIOS carrega o bootloader. Também, limpam-se os registradores e movemos o stack pointer para logo abaixo do bootloader. Essas adições são atingidas com o seguinte código:

```asm
; Set memory offset
[org 0x7c00]

; Clear some registers
xor ax, ax
mov ds, ax
mov es, ax

; Start stack at 0x8000 (right after the bootloader)
mov bp, 0x8000
mov sp, bp
```

Depois, carrega-se o kernel para a memória. Isso é feito utilizando a interrupção 0x13, que é a interrupção de leitura de disco. Também devem-se especificar o número do disco, o número do setor e o endereço de memória onde o conteúdo deve ser carregado. O código para isso é o seguinte:

```asm
; Set kernel location to 0x1000, which is the default to i386-elf-ld
KERNEL_LOCATION equ 0x1000

mov [BOOT_DISK], dl

; Load kernel into memory from disk
mov bx, KERNEL_LOCATION ; Load kernel at KERNEL_LOCATION (es is 0x0000)
mov dh, 2               ; Read 2 sectors
mov ah, 0x02
mov al, dh              ; Read 2 sectors
mov ch, 0x00            ; Cylinder 0
mov cl, 0x02            ; Sector 2
mov dh, 0x00            ; Head 0
mov dl, [BOOT_DISK]     ; Drive number
int 0x13                ; Call BIOS interrupt

; Boot disk number
BOOT_DISK: db 0
```

Em seguida, muda-se para text mode e limpa-se a tela. O código para isso é o seguinte:

```asm
; Switch to text mode and clear the screen
mov ax, 0x0003
int 0x10
```

Por fim, realiza-se a transição para protected mode. Isso permite que o bootloader acesse mais memória, além de permitir que escrevam-se códigos mais complexos e em linguagens de nível mais alto (como C++). Para isso, é necessário gerar os descritores do GDT (Global Descriptor Table). O código (comentado para facilitar o entendimento, mas uma excelente explicação encontra-se [em um dos vídeos](https://youtu.be/Wh5nPn2U_1w?t=176) da série mencionada):

```asm
; GDT
GDT_start:
  null_descriptor: ; Null descriptor
    dd 0x0
    dd 0x0
  code_descriptor:  ; Code descriptor
    dw 0xFFFF       ; first 16 bits of limit (total of 20 bits)
    dw 0            ; first 16 bits of base (total of 32 bits)
    db 0            ; next 8 bits of base (total of 32 bits, 24 used)
    db 10011010b    ; present (1), ring 0 (00), code (1), code in segment (1), conforming (0), readable (1), accessed (0)
    db 11001111b    ; granularity (1), 32-bit (1), not using last two (00), last 4 bits of limit (total of 20 bits)
    db 0            ; last 8 bits of base (total of 32 bits)
  data_descriptor:  ; Data descriptor
    dw 0xFFFF       ; first 16 bits of limit (total of 20 bits)
    dw 0            ; first 16 bits of base (total of 32 bits)
    db 0            ; next 8 bits of base (total of 32 bits, 24 used)
    db 10010010b    ; present (1), ring 0 (00), data (1), code in segment (0), expand down (0), writable (1), accessed (0)
    db 11001111b    ; granularity (1), 32-bit (1), not using last two (00), last 4 bits of limit (total of 20 bits)
    db 0            ; last 8 bits of base (total of 32 bits)
GDT_end:
GDT_descriptor:
  dw GDT_end - GDT_start - 1  ; size of GDT
  dd GDT_start                ; pointer to beginning of GDT
```

Seguindo para a transição, deve-se desabilitar as interrupções, carregar o descritor mostrado acima, setar o bit de protected mode no registrador CR0 e, por fim, realizar um jump para o código em protected mode. O código para isso é o seguinte:

```asm
; Switch to 32-bit protected mode
CODE_SEG equ code_descriptor - GDT_start  ; Compute the offset of our code segment
DATA_SEG equ data_descriptor - GDT_start  ; Compute the offset of our data segment
cli                                       ; Disable interrupts
lgdt [GDT_descriptor]                     ; Load the GDT descriptor
mov eax, cr0                              ; Get the current value of CR0
or eax, 0x1                               ; Set the first bit of CR0 to 1
mov cr0, eax                              ; Write the new value of CR0
jmp CODE_SEG:init_pm                      ; FAR JMP to set CS to our code segment

jmp $ ; Infinite loop

; Protected mode initialization
[bits 32]
init_pm:
  mov ax, DATA_SEG
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov ebp, 0x90000
  mov esp, ebp
  jmp KERNEL_LOCATION
```

Note que existe um loop infinito antes do `init_pm`. Isso é necessário pois o código em protected mode não pode ser executado no modo real. Então, o código em protected mode deve ser colocado após o loop infinito, para que o bootloader não tente executá-lo.

Combinando tudo, o código final do bootloader é o seguinte (arquivo `boot.S`):

```asm
; Set memory offset
[org 0x7c00]

; Set kernel location to 0x1000, which is the default to i386-elf-ld
KERNEL_LOCATION equ 0x1000

mov [BOOT_DISK], dl

; Clear some registers
xor ax, ax
mov ds, ax
mov es, ax

; Start stack at 0x8000 (right after the bootloader)
mov bp, 0x8000
mov sp, bp

; Load kernel into memory from disk
mov bx, KERNEL_LOCATION ; Load kernel at KERNEL_LOCATION (es is 0x0000)
mov dh, 2               ; Read 2 sectors
mov ah, 0x02
mov al, dh              ; Read 2 sectors
mov ch, 0x00            ; Cylinder 0
mov cl, 0x02            ; Sector 2
mov dh, 0x00            ; Head 0
mov dl, [BOOT_DISK]     ; Drive number
int 0x13                ; Call BIOS interrupt

; Switch to text mode and clear the screen
mov ax, 0x0003
int 0x10

; Switch to 32-bit protected mode
CODE_SEG equ code_descriptor - GDT_start  ; Compute the offset of our code segment
DATA_SEG equ data_descriptor - GDT_start  ; Compute the offset of our data segment
cli                                       ; Disable interrupts
lgdt [GDT_descriptor]                     ; Load the GDT descriptor
mov eax, cr0                              ; Get the current value of CR0
or eax, 0x1                               ; Set the first bit of CR0 to 1
mov cr0, eax                              ; Write the new value of CR0
jmp CODE_SEG:init_pm                      ; FAR JMP to set CS to our code segment

jmp $ ; Infinite loop

; Boot disk number
BOOT_DISK: db 0

; GDT
GDT_start:
  null_descriptor: ; Null descriptor
    dd 0x0
    dd 0x0
  code_descriptor:  ; Code descriptor
    dw 0xFFFF       ; first 16 bits of limit (total of 20 bits)
    dw 0            ; first 16 bits of base (total of 32 bits)
    db 0            ; next 8 bits of base (total of 32 bits, 24 used)
    db 10011010b    ; present (1), ring 0 (00), code (1), code in segment (1), conforming (0), readable (1), accessed (0)
    db 11001111b    ; granularity (1), 32-bit (1), not using last two (00), last 4 bits of limit (total of 20 bits)
    db 0            ; last 8 bits of base (total of 32 bits)
  data_descriptor:  ; Data descriptor
    dw 0xFFFF       ; first 16 bits of limit (total of 20 bits)
    dw 0            ; first 16 bits of base (total of 32 bits)
    db 0            ; next 8 bits of base (total of 32 bits, 24 used)
    db 10010010b    ; present (1), ring 0 (00), data (1), code in segment (0), expand down (0), writable (1), accessed (0)
    db 11001111b    ; granularity (1), 32-bit (1), not using last two (00), last 4 bits of limit (total of 20 bits)
    db 0            ; last 8 bits of base (total of 32 bits)
GDT_end:
GDT_descriptor:
  dw GDT_end - GDT_start - 1  ; size of GDT
  dd GDT_start                ; pointer to beginning of GDT

; Protected mode initialization
[bits 32]
init_pm:
  mov ax, DATA_SEG
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax
  mov ebp, 0x90000
  mov esp, ebp
  jmp KERNEL_LOCATION

; End of bootloader (magic number)
times 510 - ($ - $$) db 0
dw 0xAA55
```

É possível ver que ainda existe um gap a ser preenchido: o código do kernel. Conforme mencionado na introdução, será somente um código que imprime uma mensagem na tela. O código, comentado, é o seguinte (arquivo `kernel.cpp`):

```cpp
// Defines the kernel entry point
extern "C" void main()
{
    // In text mode, the screen buffer is at B8000
    // We will write a multiple-character string to it
    char *video_memory = (char *)0xb8000;
    // Write a string to the screen
    char *str = "Hello, World!";
    for (int i = 0; i < 13; i++)
    {
        video_memory[i * 2] = str[i];
        video_memory[i * 2 + 1] = 0x07;
    }
    return;
}
```

Porém, também é necessário um código assembly que chame a função `main`. Isso é feito com o seguinte código (arquivo `kernel.S`):

```asm
section .text       ; Section declaration for kernel.cpp
    [bits 32]
    [extern main]
    call main       ; Call main function
    jmp $           ; Infinite loop
```

Outra utilidade que foi gerada, por recomendações em diversos lugares, é um arquivo de zeros para preencher um espaço do disco. Isso é feito com o seguinte código (arquivo `zeroes.S`):

```asm
times 10240 db 0 ; Fill up to 10K with 0's so the disk won't fail to load
```

Agora, para gerar o binário final, é necessário compilar tudo. Primeiro, o código assembly do bootloader é compilado com o NASM:

```bash
nasm -f bin boot.S -o bin/boot.bin
```

Depois, o kernel entry point é compilado com o NASM:

```bash
nasm -f elf kernel.S -o bin/kernel_asm.o
```

Em seguida, o código C++ é compilado com o `i386-elf-gcc`:

```bash
i386-elf-gcc -ffreestanding -m32 -g -c kernel.cpp -o bin/kernel.o
```

Então, o código assembly de zeros é compilado com o NASM:

```bash
nasm -f bin zeroes.S -o bin/zeroes.bin
```

Por fim, os binários são linkados com o `i386-elf-ld`:

```bash
i386-elf-ld -o bin/full_kernel.bin -Ttext 0x1000 bin/kernel_asm.o bin/kernel.o --oformat binary
```

E o binário final é gerado com o `cat`:

```bash
cat bin/boot.bin bin/full_kernel.bin bin/zeroes.bin  > bin/OS.bin
```

Finalmente, o binário pode ser executado com o QEMU:

```bash
run qemu-system-x86_64 -drive format=raw,file=bin/OS.bin,index=0,if=floppy,  -m 128M
```
