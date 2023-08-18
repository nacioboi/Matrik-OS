org 0x7C00 ; calculate variables and labels with the offset 7C00.
bits 16 ; the cpu always starts in 16 bit mode.

%define ENDL 0x0D, 0x0A

msg_hello: db "hello world!", ENDL, 0

start:
    jmp main

; function: `puts`.
; -----------------
; description:
;   prints a string to the screen using a system interrupt.
; parameters:
;   - ds:si points to the string which one wants to print.
puts:
    push si
    push ax
.puts.loopy:
    lodsb ; loads next character into al.
    or al, al ; check if next character is null. if yes, the zero flag will be set.
    jz .puts.done

    mov ah, 0x0E ; this is the sub-category for the interupt.
    mov bh, 0
    int 0x10

    jmp .puts.loopy
.puts.done:
    pop ax
    pop si
    ret

main:
    ; setup data segments.
    ; we cannot set the stack pointer without using an intermediary register.
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; setup stack.
    mov ss, ax
    mov sp, 0x7C00

    ; say hello
    mov si, msg_hello
    call puts

; stop the computer doing stuff if the os program has ended.
.halt:
    jmp .halt

; to declare this as a legacy boot option, the last two bytes of the first sector of the disk must be 0AA55h.
; so we must pad the program so that there is our code (above) followed by a series of null bytes until the last two bytes.
times 510-($-$$) db 0
dw 0AA55h