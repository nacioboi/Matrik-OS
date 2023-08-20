org 0x7C00 		; Calculate variables and labels with the offset 0x7C00.
bits 16 		; We want to start out in 16 bit real mode.

%define ENDL 0x0D, 0x0A

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FAT 12 BPB (BIOS Parameter Block). ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
jmp short main
nop

bdb_oem: 				db "MSWIN4.1" 		; For maximum compatability, we are not using microsoft here.
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

main:
	; Setup data segments.
	; We cannot set the stack pointer without using an intermediary register.
	mov ax, 0
	mov ds, ax
	mov es, ax

	; Setup stack.
	mov ss, ax
	mov sp, 0x7C00

	; Some BIOSes might start us at 0x7C00:0000 instead of 0x0000:7C00.
	push es
	push word .start
	retf
.start:
	; Read something from disk.
	mov [ebr_drive_number], dl

	; Show loading message.
	mov si, msg_loading
	call puts

	; Compute LBA of the root directory = reserved sectors + (FAT copies * sectors per FAT).
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx
	add ax, [bdb_reserved_sectors]
	push ax

	; Compute size of the root directory = (entries * 32) / bytes per sector.
	mov ax, [bdb_sectors_per_fat]
	shl ax, 5
	xor dx, dx
	div word [bdb_bytes_per_sector]

	test dx, dx
	jz .root_dir_after
	inc ax
.root_dir_after:
	; Read the root directory.
	mov cl, al
	pop ax
	mov dl, [ebr_drive_number]
	mov bx, buffer
	call dread

	; search for kernel.
	xor bx, bx
	mov di, buffer
.search_kernel:
	mov si, file_kernel_name
	mov cx, 11
	push di
	repe cmpsb
	pop di
	je .found_kernel

	add di, 32
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .search_kernel

	mov si, msg_err_kernel_not_found
	jmp perror
.found_kernel:
	; Save first cluster of kernel.
	mov ax, [di + 26]
	mov [kernel_cluster], ax

	; Load FAT from disk.
	mov ax, [bdb_reserved_sectors]
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call dread

	; Read kernel from disk.
	mov bx, KERNEL_LOAD_SEGMENT
	mov es, bx
	mov bx, KERNEL_LOAD_OFFSET

.kernel_load_loop:
	; Read next cluster.
	mov ax, [kernel_cluster]
	mov cx, 31

	mov cl, 1
	mov dl, [ebr_drive_number]
	call dread

	add bx, [bdb_bytes_per_sector]

	; Compute the location of the next cluster.
	mov ax, [kernel_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx

	mov si, buffer
	add si, ax
	mov ax, [ds:si]

	or dx, dx
	jz .even
.odd:
	shr ax, 4
	jmp .next_cluster
.even:
	and ax, 0FFFh
.next_cluster:
	cmp ax, 0FF8h
	jae .read_finished

	mov [kernel_cluster], ax
	jmp .kernel_load_loop

.read_finished:
	mov dl, [ebr_drive_number]
	mov ax, KERNEL_LOAD_SEGMENT
	mov ds, ax
	mov es, ax

	jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

	jmp waitkp

	cli
	hlt
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; routine: lba_to_chs 									;
; ----------------------------------------------------------------------;
; description: 										;
;   Converts an LBA address to a CHS address. 					;
; paramaters: 										;
;   - dl - disk to reset. 								;
; returns: 											;
; - NONE. 											;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
dreset:
	pusha
	mov ah, 0
	stc
	int 13h
	popa
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; routine: lba_to_chs 									;
; ----------------------------------------------------------------------;
; description: 										;
;   Converts an LBA address to a CHS address. 					;
; paramaters: 										;
;   - ax - LBA adress which one wants to convert. 				;
; returns: 											;
; - cx [bits 0-5] - sector number.							;
; - cx [bits 6-15] - cylinder.							;
; - dh - head.										;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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

;;;;;;;;;;;;;;;;;;
; Other routines ;
;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;
; Memory. ;
;;;;;;;;;;;
prefix_msg_err: 				db "ERR="

msg_loading: 				db "Loading...", ENDL, 0
file_kernel_name: 			db "KERNEL   BIN"
kernel_cluster: 				dw 0
buffer:	
KERNEL_LOAD_SEGMENT: 			equ 0x2000
KERNEL_LOAD_OFFSET: 			equ 0

; Error strings.
msg_err_floppy_unreadable_device: 	db prefix_msg_err, "1", ENDL, 0
msg_err_kernel_not_found: 		db prefix_msg_err, "2", ENDL, 0

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