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
;.def shot = r17

start:
	ldi temp,low(RAMEND)
	out SPL,temp
	ldi temp,high(RAMEND)
	out SPH,temp
	
	ldi temp,$ff
	out	DDRA,temp	; Set port A as output
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
	
loop:
	rjmp loop

ext_int0:	;up button
	reti

ext_int1:	;down button
	reti

ext_int2:	;shoot button
	reti

;welcome_message:
;.db "Shooting Range!"
;.db 0