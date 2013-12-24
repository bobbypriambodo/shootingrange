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
	cbi PORTA,1	; CLR RS
	ldi PB, 0xC3
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi	ZH,high(2*welcome_message)	; Load high part of byte address into ZH
	ldi	ZL,low(2*welcome_message)	; Load low part of byte address into ZL
	rcall loadbyte
	cbi PORTA,1	; CLR RS
	ldi PB, 0x9C
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi	ZH,high(2*version)	; Load high part of byte address into ZH
	ldi	ZL,low(2*version)	; Load low part of byte address into ZL
	rcall loadbyte
	
	ldi temp, 70
	rcall delay
	rcall lcd_clear


init_elements:
	;player
	cbi PORTA,1	; CLR RS
	ldi PB, 0xC0
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 125
	rcall write_text
	;target 1
	cbi PORTA,1	; CLR RS
	ldi PB, 0x8E
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text
	;target 2
	cbi PORTA,1	; CLR RS
	ldi PB, 0xD3
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text
	;target 3
	cbi PORTA,1	; CLR RS
	ldi PB, 0xA0
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text
	;target 4
	cbi PORTA,1	; CLR RS
	ldi PB, 0xE5
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text
	;target 5
	cbi PORTA,1	; CLR RS
	ldi PB, 0x92
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text
	;target 6
	cbi PORTA,1	; CLR RS
	ldi PB, 0xCF
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text
	;target 7
	cbi PORTA,1	; CLR RS
	ldi PB, 0xA4
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text
	;target 8
	cbi PORTA,1	; CLR RS
	ldi PB, 0xE1
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	rcall lcd_wait
	ldi A, 226
	rcall write_text

;############### GAME LOOP ################
loop:
	rjmp loop

;######## INTERRUPT SERVICE ROUTINE ########
ext_int0:	;up button
	push r16
	in r16,sreg
	push r16

	rcall lcd_clear

	pop r16
	out sreg,r16
	pop r16
	reti

ext_int1:	;down button
	reti

ext_int2:	;shoot button
	push r16
	in r16,sreg
	push r16

	pop r16
	out sreg,r16
	pop r16
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
	
;############### STRINGS ################
welcome_message:
.db "Shooting Range"
.db 0,0
version:
.db "v0.1"
.db 0,0
