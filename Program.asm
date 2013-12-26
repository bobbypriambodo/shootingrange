;*************************************************************************** 
;* 
;* Title:			SHOOTING RANGE
;* Version:			1.0
;* Author:			Muhammad Ardhan Fadlurrahman
;*					Tondhy Eko Pramudya
;*					Widyanto Bagus Priambodo
;*					Yosua Lijanto Binar
;* Kelompok:		B8
;* 
;***************************************************************************

.include "m8515def.inc"

;***************************************************************************
; Address untuk program dan interrupt
;***************************************************************************
.org $000				; program awal
	rjmp start
.org $001				; external interrupt 0 (tombol UP)
	rjmp ext_int0
.org $002				; external interrupt 1 (tombol DOWN)
	rjmp ext_int1
.org $007				; timer 0 overflow interrupt
	rjmp isr_tov0
.org $00D				; external interrupt 2 (tombol SHOOT)
	rjmp ext_int2
	
;***************************************************************************
; Definisi-definisi register-register yang diperlukan
;***************************************************************************	
.def temp = r16			; temporary register
.def shot = r17			; flag apabila dilakukan tembakan (0 ketika tidak menembak dan 1 ketika menembak)
.def PB = r18			; untuk PORTB
.def A = r19			; untuk menulis karakter
.def position = r23		; untuk menyimpan posisi player
.def bullet_pos = r24	; untuk menyimpan posisi bullet
.def temp2 = r25		; temporary register dua
.def destroyed = r26	; untuk menyimpan banyak target yang sudah dijatuhkan

;***************************************************************************
; Konstanta-konstanta yang dibutuhkan program
;***************************************************************************	

;****** posisi player ******
.equ pos1 = 0x80		; baris pertama
.equ pos2 = 0xC0		; baris kedua
.equ pos3 = 0x94		; baris ketiga
.equ pos4 = 0xD4		; baris keempat

;****** posisi target ******
.equ tpos1 = 0x8D		; target 1
.equ tpos2 = 0x8F		; target 2
.equ tpos3 = 0x93		; target 3
.equ tpos4 = 0xCE		; target 4
.equ tpos5 = 0xD1		; target 5
.equ tpos6 = 0xD2		; target 6
.equ tpos7 = 0xA0		; target 7
.equ tpos8 = 0xA2		; target 8
.equ tpos9 = 0xA4		; target 9
.equ tpos10 = 0xE3		; target 10
.equ tpos11 = 0xE5		; target 11
.equ tpos12 = 0xE7		; target 12

;**** konstanta untuk CGRAM ****
.equ player_row0 = 0x18
.equ player_row1 = 0x18
.equ player_row2 = 0x11
.equ player_row3 = 0x1E
.equ player_row4 = 0x18
.equ player_row5 = 0x18
.equ player_row6 = 0x14
.equ player_row7 = 0x14

.equ bullet_row2 = 0x06

.equ target_row0 = 0x1F
.equ target_row1 = 0x11
.equ target_row2 = 0x15
.equ target_row3 = 0x15
.equ target_row4 = 0x15
.equ target_row5 = 0x11
.equ target_row6 = 0x1F
.equ target_row7 = 0x1B

;******* ASCII code untuk tiap elemen ******
.equ player = 0			; CGRAM 0
.equ bullet = 1			; CGRAM 1
.equ target = 2			; CGRAM 2
.equ space = 32			; karakter spasi (' ')

;***************************************************************************
; Macro-macro
;***************************************************************************	

;***********
; Memindahkan cursor LCD ke tempat yang diinginkan
; parameter:
;	0 => lokasi yang diinginkan (konstanta)
;***********
.macro set_cursor
	cbi PORTA,1			; CLR RS
	ldi PB,@0
	out PORTB,PB
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
.endmacro

;***********
; Memindahkan cursor LCD ke tempat yang diinginkan
; parameter:
;	0 => lokasi yang diinginkan (register)
;***********
.macro set_cursor_r
	cbi PORTA,1			; CLR RS
	mov PB,@0
	out PORTB,PB
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
.endmacro

;***********
; Memindahkan player.
; parameter:
;	0 => lokasi awal (konstanta)
;	1 => lokasi akhir (konstanta)
;***********
.macro move ;(@0: from, @1: to)
	draw @0,space		; menggambar spasi di lokasi awal
	draw @1,player		; menggambar player di lokasi akhir
	ldi position,@1		; mengupdate nilai posisi player
.endmacro

;***********
; Memindahkan bullet.
; parameter:
;	0 => lokasi awal (register)
;	1 => lokasi akhir (register)
;***********
.macro move_bullet
	draw_r @0,space		; menggambar spasi di lokasi awal
	draw_r @1,bullet	; menggambar bullet di lokasi akhir
	mov bullet_pos,@1	; mengupdate nilai posisi bullet
.endmacro

;***********
; Menggambar.
; parameter:
;	0 => lokasi gambar (konstanta)
;	1 => ASCII code yang ingin digambar (konstanta)
;***********
.macro draw
	set_cursor @0		; set cursor ke lokasi yang diinginkan
	ldi A,@1			; gambar karakter yang diinginkan
	rcall write_text	; panggil write text
.endmacro

;***********
; Menggambar.
; parameter:
;	0 => lokasi gambar (register)
;	1 => ASCII code yang ingin digambar (konstanta)
;***********
.macro draw_r
	set_cursor_r @0		; set cursor ke lokasi yang diinginkan
	ldi A,@1			; gambar karakter yang diinginkan
	rcall write_text	; panggil write text
.endmacro

;***********
; Menghancurkan elemen ketika terjadi collision.
; parameter:
;	0 => lokasi peluru (register)
;	1 => lokasi target (register)
;***********
.macro destroy
	ldi shot,0			; clear flag shot
	draw_r @0,space		; hapus peluru
	draw_r @1,space		; hapus target
	inc destroyed		; increment destroyed
.endmacro

;***************************************************************************
; Program utama
;***************************************************************************

;**************** INITIALIZATION *****************
start:
	ldi temp,low(RAMEND)
	out SPL,temp
	ldi temp,high(RAMEND)
	out SPH,temp
	
	rcall lcd_init
	rcall lcd_clear
	
	ldi temp,$ff
	out	DDRA,temp	; Set port A as output
	out	DDRB,temp	; Set port B as output
	out DDRD,temp
	out PORTD,temp
	
	ldi destroyed,0
	
;**************** SPLASH SCREEN *****************
show_welcome_message:
	set_cursor 0xC3
	ldi	ZH,high(2*welcome_message)	; Load high part of byte address into ZH
	ldi	ZL,low(2*welcome_message)	; Load low part of byte address into ZL
	rcall loadbyte
	set_cursor 0x9C
	ldi	ZH,high(2*version)	; Load high part of byte address into ZH
	ldi	ZL,low(2*version)	; Load low part of byte address into ZL
	rcall loadbyte

;**************** RESET MEMORY *****************
init_memory:
	ldi temp,0xFF
	ldi YL,tpos1
	st Y,temp
	ldi YL,tpos2
	st Y,temp
	ldi YL,tpos3
	st Y,temp
	ldi YL,tpos4
	st Y,temp
	ldi YL,tpos5
	st Y,temp
	ldi YL,tpos6
	st Y,temp
	ldi YL,tpos7
	st Y,temp
	ldi YL,tpos8
	st Y,temp
	ldi YL,tpos9
	st Y,temp
	ldi YL,tpos10
	st Y,temp
	ldi YL,tpos11
	st Y,temp
	ldi YL,tpos12
	st Y,temp

;*********** CREATING CHARACTERS *************
	rcall create_characters

;**************** LOADING *****************
	ldi temp,20;70
	rcall delay
	rcall lcd_clear

;*********** DRAWING ELEMENTS ****************
init_elements:
	draw pos2,player
	ldi position,pos2
	draw tpos1,target
	draw tpos2,target
	draw tpos3,target
	draw tpos4,target
	draw tpos5,target
	draw tpos6,target
	draw tpos7,target
	draw tpos8,target
	draw tpos9,target
	draw tpos10,target
	draw tpos11,target
	draw tpos12,target

;************* INTERRUPT ENABLING **************
int_enable:
	ldi temp,0b00001010
	out MCUCR,temp		; external interrupt 0 and 1 active on falling edge
	ldi temp,0b00000000
	out EMCUCR,temp		; external interrupt 2 active on falling edge
	ldi temp,0b11100000
	out GICR,temp		; enable external interrupt 0, 1, and 2
	ldi temp, (1<<CS01)	; (1<<CS02)|(1<<CS00) Timer clock = system clock/1024
	out TCCR0,temp			
	ldi temp,1<<TOV0
	out TIFR,temp		; Interrupt if overflow occurs in T/C0
	ldi temp,1<<TOIE0
	out TIMSK,temp		; Enable Timer/Counter0 Overflow int
	ser temp
	sei					; enable global interrupt
	
;****************** GAME LOOP ********************
loop:
	cpi destroyed,12	; check if all targets are destroyed
	breq game_over		; if so, jump to game over
	rjmp loop			; if not, loop
	
;******************* GAME OVER ********************
game_over:
	cli							; disable global interrupt
	rcall lcd_clear
	set_cursor 0x82
	ldi	ZH,high(2*game_over1)	; Load high part of byte address into ZH
	ldi	ZL,low(2*game_over1)	; Load low part of byte address into ZL
	rcall loadbyte
	set_cursor 0xC2
	ldi	ZH,high(2*game_over2)	; Load high part of byte address into ZH
	ldi	ZL,low(2*game_over2)	; Load low part of byte address into ZL
	rcall loadbyte
	set_cursor 0x9A
	ldi	ZH,high(2*game_over3)	; Load high part of byte address into ZH
	ldi	ZL,low(2*game_over3)	; Load low part of byte address into ZL
	rcall loadbyte
	set_cursor 0xD5
	ldi	ZH,high(2*game_over4)	; Load high part of byte address into ZH
	ldi	ZL,low(2*game_over4)	; Load low part of byte address into ZL
	rcall loadbyte

forever_loop:
	rjmp forever_loop

;************* INTERRUPT SERVICE ROUTINE ***************
ext_int0:					; up button
	push r16
	in r16,sreg
	push r16
	cpi position,pos1		; check if already on top
	breq isr_exit			; if on top, return
	rcall move_up			; else, move up
	rjmp isr_exit

ext_int1:					; down button
	push r16
	in r16,sreg
	push r16
	cpi position,pos4		; check if already at the bottom
	breq isr_exit			; if at the bottom, return
	rcall move_down			; else, move down
	rjmp isr_exit

ext_int2:					; shoot button
	push r16
	in r16,sreg
	push r16
	cpi shot,1				; check if already shot
	breq isr_exit			; if shot, return
	ldi shot,1				; set shot flag
	mov bullet_pos,position	; load player position to bullet position
	inc bullet_pos			; increment bullet position
	rjmp isr_exit
	
isr_tov0:					; timer
	push r16
	in r16,sreg
	push r16
	tst shot				; check if shot flag is 0
	breq isr_exit			; if 0, return
	mov temp,bullet_pos		; else, check next location
	inc temp
	rcall check_collision	; check for collision
	tst shot				; check if shot flag is 0 (collided)
	breq isr_exit			; if so, return
	move_bullet bullet_pos,temp	; else, move bullet
	
isr_exit:
	pop r16
	out sreg,r16
	pop r16
	reti
	
;************** SUBROUTINES ****************

; return
return:
	ret

; loadbyte from program memory to LCD
loadbyte:
	lpm				; Load byte from program memory into r0

	tst	r0			; Check if we've reached the end of the message
	breq return		; If so, quit

	mov A, r0		; Put the character onto Port B
	rcall write_text
	adiw ZL,1		; Increase Z registers
	rjmp loadbyte

; for delay
delay:
	dec temp
	breq return
	rcall lcd_wait
	rjmp delay

; delay LCD
lcd_wait:
	ldi	r20, 255
	ldi	r21, 255
	ldi	r22, 255
cont:	dec	r22
	brne	cont
	ldi	r22, 2
	dec	r21
	brne	cont
	ldi	r21, 2
	dec	r20
	brne	cont
	ldi	r20, 2
	ret

; initialize LCD
lcd_init:
	cbi PORTA,1			; CLR RS
	ldi PB,0x38			; MOV DATA,0x38 --> 8bit, 2line, 5x7
	out PORTB,PB
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
	rcall lcd_wait
	cbi PORTA,1			; CLR RS
	ldi PB,$0C			; MOV DATA,0x0E --> disp ON, cursor OFF, blink OFF
	out PORTB,PB
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
	rcall lcd_wait
	cbi PORTA,1			; CLR RS
	ldi PB,$06			; MOV DATA,0x06 --> increase cursor, display sroll OFF
	out PORTB,PB
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
	rcall lcd_wait
	ret

; clear LCD
lcd_clear:
	cbi PORTA,1			; CLR RS
	ldi PB,$01			; MOV DATA,0x01
	out PORTB,PB
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
	ret

; write to LCD
write_text:
	sbi PORTA,1			; SETB RS
	out PORTB, A
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
	ret

; creating CGRAM characters
create_characters:
	cbi PORTA,1			; CLR RS
	ldi PB,0b01000000	; CGRAM address 0
	out PORTB,PB
	sbi PORTA,0			; SETB EN
	cbi PORTA,0			; CLR EN
	rcall lcd_wait
	
	; creating player
	ldi A,player_row0
	rcall write_text
	ldi A,player_row1
	rcall write_text
	ldi A,player_row2
	rcall write_text
	ldi A,player_row3
	rcall write_text
	ldi A,player_row4
	rcall write_text
	ldi A,player_row5
	rcall write_text
	ldi A,player_row6
	rcall write_text
	ldi A,player_row7
	rcall write_text
	
	; creating bullet
	ldi A,0
	rcall write_text
	ldi A,0
	rcall write_text
	ldi A,bullet_row2
	rcall write_text
	ldi A,0
	rcall write_text
	ldi A,0
	rcall write_text
	ldi A,0
	rcall write_text
	ldi A,0
	rcall write_text
	ldi A,0
	rcall write_text
	
	; creating target
	ldi A,target_row0
	rcall write_text
	ldi A,target_row1
	rcall write_text
	ldi A,target_row2
	rcall write_text
	ldi A,target_row3
	rcall write_text
	ldi A,target_row4
	rcall write_text
	ldi A,target_row5
	rcall write_text
	ldi A,target_row6
	rcall write_text
	ldi A,target_row7
	rcall write_text
	ret

; move up
move_up:
	cpi position,pos2
	breq up_to_pos1
	cpi position,pos3
	breq up_to_pos2
	rjmp up_to_pos3
up_to_pos1:
	move pos2,pos1
	ret
up_to_pos2:
	move pos3,pos2
	ret
up_to_pos3:
	move pos4,pos3
	ret

; move down
move_down:
	cpi position,pos1
	breq down_to_pos2
	cpi position,pos2
	breq down_to_pos3
	rjmp down_to_pos4
down_to_pos2:
	move pos1,pos2
	ret
down_to_pos3:
	move pos2,pos3
	ret
down_to_pos4:
	move pos3,pos4
	ret

; collision check
check_collision:
	; check if collided
	cpi temp,tpos1
	breq collided
	cpi temp,tpos2
	breq collided
	cpi temp,tpos3
	breq collided
	cpi temp,tpos4
	breq collided
	cpi temp,tpos5
	breq collided
	cpi temp,tpos6
	breq collided
	cpi temp,tpos7
	breq collided
	cpi temp,tpos8
	breq collided
	cpi temp,tpos9
	breq collided
	cpi temp,tpos10
	breq collided
	cpi temp,tpos11
	breq collided
	cpi temp,tpos12
	breq collided
	; check if out of bounds
	cpi temp,0x94
	breq out_of_bounds
	cpi temp,0xD4
	breq out_of_bounds
	cpi temp,0xA8
	breq out_of_bounds
	cpi temp,0xE8
	breq out_of_bounds
	rjmp col_exit
collided:
	mov YL,temp
	ldi YH,0
	ld temp2,Y
	cpi temp2,1
	breq col_exit
	destroy bullet_pos,temp
	ldi temp2,1
	st Y, temp2 ;add tpos to memory
	rjmp col_exit
out_of_bounds:
	ldi shot,0
	draw_r bullet_pos,space
col_exit:
	ret

;************** STRINGS ****************
welcome_message:
.db "Shooting Range"
.db 0,0
version:
.db "v1.0"
.db 0,0
game_over1:
.db "Congratulations!"
.db 0,0
game_over2:
.db "You have beaten "
.db 0,0
game_over3:
.db "the game. "
.db 0,0
game_over4:
.db "Please play again!"
.db 0,0
