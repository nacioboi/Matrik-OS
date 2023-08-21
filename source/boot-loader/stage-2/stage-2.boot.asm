bits 16

section _ENTRY class=CODE

extern _cstart_
global entry

entry:
	cli
	mov ax, ds
	mov ss, ax
	mov sp, 0
	mov bp, sp
	sti

	; Expect boot drive in dl, send it to the cstart function.
	xor dh, dh
	push dx
	call _cstart_

	cli
	hlt