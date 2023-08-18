org 0x7C00 ; calculate variables and labels with the offset 7C00.
bits 16 ; the cpu always starts in 16 bit mode.

%define ENDL 0x0D, 0x0A


;
; FAT 12 Header
;
jmp short start
nop

bdb_oem:                    db "MSWIN4.1" ; for maximum compatability, we are not using microsoft here.
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_clustor:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0F0h
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record.
ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 00h, 00h, 00h, 00h
ebr_volume_label:           db "MATRIK OS  "
ebr_system_id:              db "FAT12   "

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

msg_hello: db "hello world!", ENDL, 0

; to declare this as a legacy boot option, the last two bytes of the first sector of the disk must be 0AA55h.
; so we must pad the program so that there is our code (above) followed by a series of null bytes until the last two bytes.
times 510-($-$$) db 0
dw 0AA55h