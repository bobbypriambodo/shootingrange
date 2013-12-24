.include "m8515def.inc"

.org $000
	rjmp start
.org $001
	rjmp ext_int0
.org $002
	rjmp ext_int1
.org $00D
	rjmp ext_int2

.def temp = r16
.def shot = r17
.def PB = r18	; for PORTB
.def A  = r19
.def position = r23

.equ pos1 = 0x80
.equ pos2 = 0xC0
.equ pos3 = 0x94
.equ pos4 = 0xD4

.equ player = 125
.equ target = 226
.equ space = 32

.macro set_cursor ;(@0: to)
	cbi PORTA,1	; CLR RS
	ldi PB,@0
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
.endmacro

.macro move ;(@0: from, @1: to)
	draw @0,space
	draw @1,player
	ldi position,@1
.endmacro

.macro draw ;(@0: at, @1: asciicode)
	set_cursor @0
	ldi A,@1
	rcall write_text
.endmacro

;############### INITIALIZATION ################
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

int_enable:
	ldi temp,0b00001010
	out MCUCR,temp		; external interrupt 0 and 1 active on falling edge
	ldi temp,0b00000000
	out EMCUCR,temp		; external interrupt 2 active on falling edge
	ldi temp,0b11100000
	out GICR,temp		; enable external interrupt 0, 1, and 2
	sei					; enable global interrupt
	
;############### SPLASH SCREEN ################
show_welcome_message:
	set_cursor 0xC3
	ldi	ZH,high(2*welcome_message)	; Load high part of byte address into ZH
	ldi	ZL,low(2*welcome_message)	; Load low part of byte address into ZL
	rcall loadbyte
	set_cursor 0x9C
	ldi	ZH,high(2*version)	; Load high part of byte address into ZH
	ldi	ZL,low(2*version)	; Load low part of byte address into ZL
	rcall loadbyte
	
	ldi temp,20;70
	rcall delay
	rcall lcd_clear

init_elements:
	;player
	draw pos3,player
	ldi position,pos3
	;target 1
	draw 0x8E,target
	;target 2
	draw 0xD3,target
	;target 3
	draw 0xA0,target
	;target 4
	draw 0xE5,target
	;target 5
	draw 0x92,target
	;target 6
	draw 0xCF,target
	;target 7
	draw 0xA4,target
	;target 8
	draw 0xE1,target
	
;############### GAME LOOP ################
loop:
	rjmp loop

;######## INTERRUPT SERVICE ROUTINE ########
ext_int0:	;up button
	push r16
	in r16,sreg
	push r16
	cpi position,pos1
	breq exit0
	rcall move_up
exit0:
	pop r16
	out sreg,r16
	pop r16
	reti

ext_int1:	;down button
	push r16
	in r16,sreg
	push r16
	cpi position,pos4
	breq exit1
	rcall move_down
exit1:
	pop r16
	out sreg,r16
	pop r16
	reti

ext_int2:	;shoot button
	reti
	
;############### SUBROUTINES ################
return:
	ret

loadbyte:
	lpm				; Load byte from program memory into r0

	tst	r0			; Check if we've reached the end of the message
	breq return	; If so, quit

	mov A, r0		; Put the character onto Port B
	rcall write_text
	adiw ZL,1		; Increase Z registers
	rjmp loadbyte

delay:
	dec temp
	breq return
	rcall lcd_wait
	rjmp delay

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

lcd_init:
	cbi PORTA,1	; CLR RS
	ldi PB,0x38	; MOV DATA,0x38 --> 8bit, 2line, 5x7
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	cbi PORTA,1	; CLR RS
	ldi PB,$0C	; MOV DATA,0x0E --> disp ON, cursor OFF, blink OFF
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	cbi PORTA,1	; CLR RS
	ldi PB,$06	; MOV DATA,0x06 --> increase cursor, display sroll OFF
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ret

lcd_clear:
	cbi PORTA,1	; CLR RS
	ldi PB,$01	; MOV DATA,0x01
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ret

write_text:
	sbi PORTA,1	; SETB RS
	out PORTB, A
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ret

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

;############### STRINGS ################
welcome_message:
.db "Shooting Range"
.db 0,0
version:
.db "v0.1"
.db 0,0
