org 0x0 ; we are now in the kernel.
bits 16 ; the cpu always starts in 16 bit mode.

%define ENDL 0x0D, 0x0A


main:
	; say hello
	mov si, msg_hello
	call puts

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

; stop the computer doing stuff if the os program has ended.
.halt:
	jmp .halt

msg_hello: db "hello world!", ENDL, 0