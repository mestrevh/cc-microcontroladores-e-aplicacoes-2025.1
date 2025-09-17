;
; projeto1.asm
;
; Created: 16/09/2025 10:43:08
; Author : VictorHugo
;


.def temp = r16
.def count_u = r17
.def count_d = r18
.def state = r19
.equ display1 = 0b00010000 ;quinto bit settado
.equ display2 = 0b00100000 ;sexto bit settado
.cseg

.org 0x0000
jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

reset:
	#define CLOCK 16.0e6
	.equ PRESCALE = 0b101 ; verifique no datasheet ou slide
	.equ PRESCALE_DIV = 1024; verifique no datasheet ou slide
	#define DELAY 0.05 ; 1 micro-segundos
	.equ WGM = 0b0100 ; configuração do ctc
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY)) ; de 0 até 65535
	.if TOP > 65535
	.error "TOP is out for range"
	.endif

	;configuração do TOP
	ldi temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp

	;configuração do CS
	ldi temp, ((WGM&0b11) << WGM10)
	sts TCCR1A, temp

	;iniciar a contagem
	ldi temp, ((WGM >> 2) << WGM12) | (PRESCALE << CS10)
	sts TCCR1B, temp

	ldi temp, (1<<OCIE1A)
	sts TIMSK1, temp

	; todos os pinos da PORTC como saída
	ldi temp, (1 << PCINT8) | (1 << PCINT9) | (1 << PCINT10) | (1 << PCINT11) | (1 << PCINT12) | (1 << PCINT13)
	out DDRC, temp

	; todos os pinos da PORTD (semaforo 3 e 4)
	ldi temp, (1 << PCINT23) | (1 << PCINT22) | (1 << PCINT21) | (1 << PCINT20) | (1 << PCINT19) | (1 << PCINT18) | (1 << PCINT17) | (1 << PCINT16)
	out DDRD, temp

	; todos os pinos da temp como saída (semaforo 1 e 2)
	ldi temp, (1 << PCINT5) | (1 << PCINT4) | (1 << PCINT3) | (1 << PCINT2) | (1 << PCINT1) | (1 << PCINT0)
	out DDRB, temp

	sei
	
main:
	;enviando os bits do led para unidades
	mov temp, count_u
	ori temp, display2; 0b00010000 - display 2
	out PORTC, temp
	
	;enviando os bits do led para dezenas
	mov temp, count_d
	ori temp, display1; 0b00100000 - display 1
	out PORTC, temp

	mov state, count_d

	; trocar os 4 primeiros bits
	swap state            
	andi state, 0xF0

	; completanto o bits do reg. led
	or state, count_u
	
	cpi state, 0b00000000 ; 0
	breq state_one

	cpi state, 0b00000101 ; 5
	breq state_two

	cpi state, 0b00010000 ; 10
	breq state_three

	cpi state, 0b00010101 ; 15
	breq state_four

	cpi state, 0b00100000 ; 20
	breq state_five

	cpi state, 0b00100101 ; 25
	breq state_six

	cpi state, 0b00110000 ; 30
	breq state_seven

	cpi state, 0b00110101 ; 35
	breq zero

	rjmp main

	state_one:
		ldi temp, 0b10010000
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp
		rjmp main

	state_two:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00100001
		out PORTB, temp
		rjmp main

	state_three:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00100010
		out PORTB, temp
		rjmp main

	state_four:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00001100
		out PORTB, temp
		rjmp main

	state_five:
		ldi temp, 0b01010000
		out PORTD, temp

		ldi temp, 0b00010100
		out PORTB, temp
		rjmp main

	state_six:
		ldi temp, 0b10000100
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp
		rjmp main

	state_seven:
		ldi temp, 0b10001000
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp
		rjmp main

	zero:
		ldi count_u, 0x00
		ldi count_d, 0x00

	rjmp main


OCI1A_Interrupt:
	push temp
	in temp, SREG
	push temp

	;contar unidade
	inc count_u

	;comparar quando a unidade chegar em '10'
	cpi count_u, 10
	brne skip

	; zerar unidades
	ldi count_u, 0x00

	;contar dezenas
	inc count_d

	;comparar quando a unidade chegar em '10'
	cpi count_d, 10
	brne skip

	;zerar dezenas
	ldi count_d, 0x00

	skip:
		
		; colocar o valor de count_d em led
		;mov led, count_d

		; trocar os 4 primeiros bits
		;swap led            
		;andi led, 0xF0

		; completanto o bits do reg. led
		;or led, count_u
		
		;ldi s1, 0x01
		;andi s1, count_u

		;out PORTD, led

	pop temp
	out SREG, temp
	pop temp
	reti