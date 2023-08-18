org 0x7C00 		; Calculate variables and labels with the offset 0x7C00.
bits 16 		; We want to start out in 16 bit real mode.

%define ENDL 0x0D, 0x0A

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FAT 12 BPB (BIOS Parameter Block). ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
jmp short start
nop

bdb_oem: 				db "MSWIN4.1" 	; For maximum compatability, we are not using microsoft here.
bdb_bytes_per_sector: 		dw 512
bdb_sectors_per_clustor: 	db 1
bdb_reserved_sectors: 		dw 1
bdb_fat_count: 			db 2
bdb_dir_entries_count: 		dw 0E0h
bdb_total_sectors: 		dw 2880
bdb_media_descriptor_type: 	db 0F0h
bdb_sectors_per_fat: 		dw 9
bdb_sectors_per_track: 		dw 18
bdb_heads: 				dw 2
bdb_hidden_sectors: 		dd 0
bdb_large_sector_count: 	dd 0

; Extended boot record.
ebr_drive_number: 		db 0
 					db 0
ebr_signature: 			db 29h
ebr_volume_id: 			db 00h, 00h, 00h, 00h
ebr_volume_label: 		db "MATRIK OS  " 		; 11 bytes.
ebr_system_id: 			db "FAT12   " 		; 8 bytes.

start:
	jmp main

;;;;;;;;;;;;;;;;;
; Disk routines ;
;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; routine: dread. 									;
; ----------------------------------------------------------------------;
; description: 										;
;   Reads sectors from a disk. 							;
; paramaters: 										;
;   - ax - LBA address. 								;
;   - cl - number of sectors to read (up to 126). 				;
;   - dl - drive num. 									;
;   - es:bx - memory address where to store the read data. 			;
; returns: 											;
; - NONE. 											;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
dread:
	push ax
	push bx
	push cx
	push dx
	push di

	push cx             ; temp save cl, the number of sectors to read.
	call lba_to_chs
	pop ax              ; AL = number of sectors to read
	mov ah, 02h
	mov di, 3           ; retry count
.dread.retry:
	pusha
	stc                 ; set carry flag, this is how we check the success... if the carry flag is cleared == done
	int 13h
	jnc .dread.done

	; read failed
	popa
	call dreset
	dec di
	test di, di
	jnz .dread.retry
.dread.fail:
	; all retries failed.
	mov si, msg_err_floppy_unreadable_device
	jmp perror
.dread.done:
	popa
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; routine: lba_to_chs
; -------------------
; description:
;   Converts an LBA address to a CHS address.
; paramaters:
;   - dl - disk to reset.
; returns:
; - NONE.
dreset:
	pusha
	mov ah, 0
	stc
	int 13h
	popa
	ret

; routine: lba_to_chs
; -------------------
; description:
;   Converts an LBA address to a CHS address.
; paramaters:
;   - ax - LBA adress which one wants to convert.
; returns:
; - cx [bits 0-5] - sector number.
; - cx [bits 6-15] - cylinder.
; - dh - head
lba_to_chs:
	push ax
	push dx

	xor dx, dx                          ; clear dx
	div word [bdb_sectors_per_track]    ; ax = LBA / sectors per track
							; dx = LBA % sectors per track

	inc dx                              ; dx = (LBA % sectors per track + 1) = sector
	mov cx, dx

	xor dx, dx
	div word [bdb_heads]                ; ax = (LBA / sectors per track) / heads = cylinder
							; dx = (LBA . sectors per track) % heads = head

	mov dh, dl                          ; dh = head
	mov ch, al
	shl ah, 6
	or cl, ah                           ; upper 2 bits of cylinder into cl

	pop dx
	mov dl, al
	pop ax
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

	; read something from disk.
	mov [ebr_drive_number], dl
	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call dread

	; say hello
	mov si, msg_hello
	call puts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Routine: `waitkp`. 									;
; ----------------------------------------------------------------------;
; Description: 										;
; 	Waits for a keypress. 								;
; parameters: 										;
; 	- NONE. 										;
; returns: 											;
; 	- NONE. 										;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
waitkp:
	pusha
	mov ah, 0
	int 16h ; wait for keypress
	popa
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Routine: `perror`. 									;
; ----------------------------------------------------------------------;
; Description: 										;
; 	Prints an error message to the screen, waits for a keypress, 	;
; 	and then finally reboots the computer. 					;
; parameters: 										;
; 	- ds:si - Points to the error message which one wants to print. 	;
; returns: 											;
; 	- NONE. 										;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
perror:
	call puts
	jmp waitkp
	jmp 0FFFFh:0
	hlt 			; just in case the jump fails.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Routine: `puts`. 								;
; ----------------------------------------------------------------;
; Description: 									;
; 	Prints a string to the screen using a system interrupt. 	;
; parameters: 									;
; 	- ds:si - Points to the string which one wants to print. 	;
; returns: 										;
; 	- NONE. 									;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
puts:
	push si
	push ax
.puts.loopy:
	lodsb 		; loads next character into al.
	or al, al 		; check if next character is null. if yes, the zero flag will be set.
	jz .puts.done

	mov ah, 0x0E 	; this is the sub-category for the interupt.
	mov bh, 0
	int 0x10

	jmp .puts.loopy
.puts.done:
	pop ax
	pop si
	ret

;;;;;;;;;;;;;
; Messages. ;
;;;;;;;;;;;;;
prefix_msg_err_floppy: 			db "B_ERR="

; OK strings.
msg_loading: 				db "Loading", ENDL, 0

; Error strings.
msg_err_floppy_unreadable_device: 	db prefix_msg_err_floppy, "1", ENDL, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Shit we don't care about ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; stop the computer doing stuff if the os program has ended.
.halt:
	cli ; disable inturrupts.
	jmp .halt

;;;;;;;;;;;;;;;;;;;;;
; This we do though ;
;;;;;;;;;;;;;;;;;;;;;

; to declare this as a legacy boot option, the last two bytes of the first sector of the disk must be 0AA55h.
; so we must pad the program so that there is our code (above) followed by a series of null bytes until the last two bytes.
times 510-($-$$) db 0
dw 0AA55h