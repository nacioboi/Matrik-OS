org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; FAT 12 BPB (BIOS Parameter Block). ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

jmp short start
nop

bdb_oem:				db 'MSWIN4.1'		; 8 Bytes. `MSWIN4.1` is for maximum compatibility.
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:			db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:		dw 2880			; 2880 * 512 = 1.44MB.
bdb_media_descriptor_type:	db 0F0h			; F0 = 3.5" Floppy disk.
bdb_sectors_per_fat:		dw 9				; 9 Sectors per FAT.
bdb_sectors_per_track:		dw 18
bdb_heads:				dw 2
bdb_hidden_sectors:		dd 0
bdb_large_sector_count:		dd 0

; Extended boot record
ebr_drive_number:			db 0				; 0x00 Floppy, 0x80 HDD.
					db 0				; Reserved.
ebr_signature:			db 29h
ebr_volume_id:			db 12h, 34h, 56h, 78h	; Serial number, value doesn't matter.
ebr_volume_label:			db 'MATRIK   OS'		; 11 Bytes, padded with spaces/
ebr_system_id:			db 'FAT12   '		; 8 Bytes also padded with spaces.



start:
	; Setup data segments.
	mov ax, 0			; can't set ds/es directly
	mov ds, ax
	mov es, ax
	
	; Setup stack.
	mov ss, ax
	mov sp, 0x7C00		; stack grows downwards from where we are loaded in memory

	; Some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the
	; expected location.
	push es
	push word .after
	retf
.after:
	; BIOS should set DL to drive number.
	mov [ebr_drive_number], dl

	; Show loading message.
	mov si, msg_loading
	call put_string

	; Read drive parameters (sectors per track and head count),
	; instead of relying on data on formatted disk.
	push es
	mov ah, 08h
	int 13h
	jc floppy_error
	pop es

	and cl, 0x3F				; Remove top 2 bits.
	xor ch, ch
	mov [bdb_sectors_per_track], cx	; Sector count.

	inc dh
	mov [bdb_heads], dh			; Head count.

	; Compute LBA of root directory = reserved + fats * sectors_per_fat
	; note: this section can be hardcoded.
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx					; ax = (fats * sectors_per_fat)
	add ax, [bdb_reserved_sectors]	; ax = LBA of root directory
	push ax

	; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
	mov ax, [bdb_dir_entries_count]
	shl ax, 5					; ax *= 32
	xor dx, dx					; dx = 0
	div word [bdb_bytes_per_sector]	; number of sectors we need to read

	test dx, dx					; if dx != 0, add 1
	jz .root_dir_after
	inc ax					; division remainder != 0, add 1
							; this means we have a sector only partially filled with entries
.root_dir_after:
	; read root directory
	mov cl, al					; cl = number of sectors to read = size of root directory
	pop ax					; ax = LBA of root directory
	mov dl, [ebr_drive_number]		; dl = drive number (we saved it previously)
	mov bx, buffer				; es:bx = buffer
	call disk_read

	; search for stage-2.bin
	xor bx, bx
	mov di, buffer

	.search_stage_2:
	mov si, file_stage_2_bin
	mov cx, 11					; compare up to 11 characters
	push di
	repe cmpsb
	pop di
	je .found_stage_2

	add di, 32
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .search_stage_2

	; stage 2 not found
	jmp stage_2_not_found_error
.found_stage_2:
	; di should have the address to the entry
	mov ax, [di + 26]				; first logical cluster field (offset 26)
	mov [stage_2_cluster], ax

	; load FAT from disk into memory
	mov ax, [bdb_reserved_sectors]
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read

	; read stage 2 process FAT chain
	mov bx, STAGE_2_LOAD_SEGMENT
	mov es, bx
	mov bx, STAGE_2_LOAD_OFFSET
.load_stage_2_loop:
	; Read next cluster
	mov ax, [stage_2_cluster]
	
	; not nice :( hardcoded value
	add ax, 31					; first cluster = (stage_2_cluster - 2) * sectors_per_cluster + start_sector
							; start sector = reserved + fats + root directory size = 1 + 18 + 134 = 33
	mov cl, 1
	mov dl, [ebr_drive_number]
	call disk_read

	add bx, [bdb_bytes_per_sector]

	; compute location of next cluster
	mov ax, [stage_2_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx					; ax = index of entry in FAT, dx = cluster mod 2

	mov si, buffer
	add si, ax
	mov ax, [ds:si]				; read entry from FAT table at index ax

	or dx, dx
	jz .even
.odd:
	shr ax, 4
	jmp .next_cluster_after
.even:
	and ax, 0x0FFF
.next_cluster_after:
	cmp ax, 0x0FF8				; end of chain
	jae .read_finish

	mov [stage_2_cluster], ax
	jmp .load_stage_2_loop
.read_finish:
	; jump to our stage 2
	mov dl, [ebr_drive_number]		; boot device in dl

	mov ax, STAGE_2_LOAD_SEGMENT		; set segment registers
	mov ds, ax
	mov es, ax

	jmp STAGE_2_LOAD_SEGMENT:STAGE_2_LOAD_OFFSET

	jmp wait_key_and_reboot			; should never happen

	cli						; disable interrupts, this way CPU can't get out of "halt" state
	hlt



;;;;;;;;;;;;;;;;;;
; Error handlers ;
;;;;;;;;;;;;;;;;;;

floppy_error:
	mov si, msg_read_failed
	call put_string
	jmp wait_key_and_reboot

stage_2_not_found_error:
	mov si, msg_stage_2_not_found
	call put_string
	jmp wait_key_and_reboot





;;;;;;;;;;;;;;;;;;
; Other routines ;
;;;;;;;;;;;;;;;;;;

wait_key_and_reboot:
	mov ah, 0
	int 16h					; wait for keypress
	jmp 0FFFFh:0				; jump to beginning of BIOS, should reboot

.halt:
	cli						; disable interrupts, this way CPU can't get out of "halt" state
	hlt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; * `put_string`. 								;
; ----------------------------------------------------------------;
; Description: 									;
; 	* Prints a string to the screen using a system interrupt. 	;
; Parameters: 									;
; 	* ES:SI 		* Points to the string which one wants 	;
; 				* 	to print.					;
; Returns: 										;
; 	* NONE. 									;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
put_string:
	; save registers we will modify
	push si
	push ax
	push bx
.loop:
	lodsb				; loads next character in al
	or al, al			; verify if next character is null?
	jz .done

	mov ah, 0x0E		; call bios interrupt
	mov bh, 0			; set page number to 0
	int 0x10

	jmp .loop
.done:
	pop bx
	pop ax
	pop si
	ret



;;;;;;;;;;;;;;;;;
; Disk routines ;
;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; * `disk_lba_to_chs` 									;
; ----------------------------------------------------------------------;
; Description: 										;
; 	* Converts an LBA address to a CHS address. 				;
; Paramaters: 										;
; 	* AX 			* LBA adress which one wants to convert. 		;
; Returns: 											;
; 	* CX [bits 0-5] 	* sector number. 						;
; 	* CX [bits 6-15] 	* cylinder. 						;
; 	* DH 			* head. 							;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disk_lba_to_chs:
	push ax
	push dx

	xor dx, dx						; dx = 0
	div word [bdb_sectors_per_track]		; ax = LBA / SectorsPerTrack
								; dx = LBA % SectorsPerTrack

	inc dx						; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx						; cx = sector

	xor dx, dx						; dx = 0
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / Heads = cylinder
								; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl						; dh = head
	mov ch, al						; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah						; put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al						; restore DL
	pop ax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; * `disk_read.` 										;
; ----------------------------------------------------------------------;
; Description: 										;
; 	* Reads sectors from a disk. 							;
; Paramaters: 										;
; 	* AX 		* LBA address. 							;
; 	* CL 		* number of sectors to read (up to 126). 			;
; 	* DL 		* drive num. 							;
; 	* ES:BX 	* memory address where to store the read data. 		;
; Returns: 											;
; 	* NONE. 										;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disk_read:
	push ax					; save registers we will modify
	push bx
	push cx
	push dx
	push di

	push cx					; temporarily save CL (number of sectors to read)
	call disk_lba_to_chs			; compute CHS
	pop ax					; AL = number of sectors to read
	
	mov ah, 02h
	mov di, 3					; retry count
.retry:
	pusha						; save all registers, we don't know what bios modifies
	stc						; set carry flag, some BIOS'es don't set it
	int 13h					; carry flag cleared = success
	jnc .done					; jump if carry not set

	; read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry
.fail:
	; all attempts are exhausted
	jmp floppy_error
.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax					; restore registers modified
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; * `disk_reset` 										;
; ----------------------------------------------------------------------;
; Description: 										;
; 	* Converts an LBA address to a CHS address. 				;
; Paramaters: 										;
; 	* DL 		* disk to reset. 							;
; Returns: 											;
; 	* NONE. 										;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret



;;;;;;;;;;;
; Memory. ;
;;;;;;;;;;;

msg_loading:			db 'Loading...', ENDL, 0
msg_read_failed:			db 'Read from disk failed!', ENDL, 0
msg_stage_2_not_found:		db '`STAGE-2.BIN` not found!', ENDL, 0
file_stage_2_bin:			db 'STAGE-2 BIN'
stage_2_cluster:			dw 0

STAGE_2_LOAD_SEGMENT		equ 0x2000
STAGE_2_LOAD_OFFSET		equ 0



times 510-($-$$) db 0
dw 0AA55h



buffer: