.include "m8515def.inc"

.org $000
	rjmp start
.org $001
	rjmp ext_int0
.org $002
	rjmp ext_int1
.org $007
	rjmp isr_tov0
.org $00D
	rjmp ext_int2

.def temp = r16
.def shot = r17
.def PB = r18 ; for PORTB
.def A = r19
.def position = r23
.def bullet_pos = r24
.def temp2 = r25
.def destroyed = r26

.equ pos1 = 0x80
.equ pos2 = 0xC0
.equ pos3 = 0x94
.equ pos4 = 0xD4

.equ tpos1 = 0x8D
.equ tpos2 = 0x8F
.equ tpos3 = 0x93
.equ tpos4 = 0xCE
.equ tpos5 = 0xD1
.equ tpos6 = 0xD2
.equ tpos7 = 0xA0
.equ tpos8 = 0xA2
.equ tpos9 = 0xA4
.equ tpos10 = 0xE3
.equ tpos11 = 0xE5
.equ tpos12 = 0xE7

.equ player = 125
.equ target = 79
.equ space = 32
.equ bullet = 43

.macro set_cursor ;(@0: to)
	cbi PORTA,1	; CLR RS
	ldi PB,@0
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	;rcall lcd_wait
.endmacro

.macro set_cursor_r ;(@0: to)
	cbi PORTA,1	; CLR RS
	mov PB,@0
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	;rcall lcd_wait
.endmacro

.macro move ;(@0: from, @1: to)
	draw @0,space
	draw @1,player
	ldi position,@1
.endmacro

.macro move_bullet ;(@0: from, @1: to)
	draw_r @0,space
	draw_r @1,bullet
	mov bullet_pos,@1
.endmacro

.macro draw ;(@0: at, @1: asciicode)
	set_cursor @0
	ldi A,@1
	rcall write_text
.endmacro

.macro draw_r ;(@0: at, @1: asciicode)
	set_cursor_r @0
	ldi A,@1
	rcall write_text
.endmacro

.macro destroy ;(@0: tpos)
	ldi shot,0;change flag shot
	draw_r @0,space;erase at tpos
	draw_r @1,space;erase at tpos
	inc destroyed;increment destroyed
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

	ldi destroyed,0
	
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

	ldi temp,20;70
	rcall delay
	rcall lcd_clear


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
	
;############### GAME LOOP ################
loop:
	cpi destroyed,12
	breq game_over
	rjmp loop

game_over:
	cli
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

;######## INTERRUPT SERVICE ROUTINE ########
ext_int0:	;up button
	push r16
	in r16,sreg
	push r16
	cpi position,pos1
	breq isr_exit
	rcall move_up
	rjmp isr_exit

ext_int1:	;down button
	push r16
	in r16,sreg
	push r16
	cpi position,pos4
	breq isr_exit
	rcall move_down
	rjmp isr_exit

ext_int2:	;shoot button
	push r16
	in r16,sreg
	push r16
	cpi shot,1
	breq isr_exit
	ldi shot,1
	mov bullet_pos,position
	inc bullet_pos
	rjmp isr_exit
	
isr_tov0:
	push r16
	in r16,sreg
	push r16
	tst shot
	breq isr_exit
	mov temp,bullet_pos
	inc temp
	rcall check_collision
	tst shot
	breq isr_exit
	move_bullet bullet_pos,temp
	
isr_exit:
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
	;rcall lcd_wait
	cbi PORTA,1	; CLR RS
	ldi PB,$0C	; MOV DATA,0x0E --> disp ON, cursor OFF, blink OFF
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	;rcall lcd_wait
	cbi PORTA,1	; CLR RS
	ldi PB,$06	; MOV DATA,0x06 --> increase cursor, display sroll OFF
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	;rcall lcd_wait
	ret

lcd_clear:
	cbi PORTA,1	; CLR RS
	ldi PB,$01	; MOV DATA,0x01
	out PORTB,PB
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	;rcall lcd_wait
	ret

write_text:
	sbi PORTA,1	; SETB RS
	out PORTB, A
	sbi PORTA,0	; SETB EN
	cbi PORTA,0	; CLR EN
	;rcall lcd_wait
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

check_collision:
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


;############### STRINGS ################
welcome_message:
.db "Shooting Range"
.db 0,0
version:
.db "v0.9"
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
