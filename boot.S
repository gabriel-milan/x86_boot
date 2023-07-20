; Set memory offset
[org 0x7c00]

; Set kernel location to 0x1000, which is the default to i386-elf-ld
KERNEL_LOCATION equ 0x1000

; TODO: review
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
init_pm:            ; TODO: review
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