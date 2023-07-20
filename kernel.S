section .text       ; Section declaration for kernel.cpp
    [bits 32]
    [extern main]
    call main       ; Call main function
    jmp $           ; Infinite loop