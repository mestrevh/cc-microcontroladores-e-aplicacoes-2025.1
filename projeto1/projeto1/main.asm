;
; projeto1.asm
;
; Created: 16/09/2025 10:43:08
; Author : VictorHugo
;

#define CLOCK 16.0e6 ; 16.0e6 s
#define DELAY 1 ; 1 micro-segundos

.def temp = r16
.def count_u = r17
.def count_d = r18
.def state = r19
.def timer = r20
.equ display1 = 0b00010000 ;quinto bit settado
.equ display2 = 0b00100000 ;sexto bit settado

.cseg

.org 0x0000
jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

reset:

	;CONFIGURAÇÃO DO TIMER
	
	.equ PRESCALE = 0b101 ; verifique no datasheet ou slide
	.equ PRESCALE_DIV = 1024; verifique no datasheet ou slide
	
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

	; CONFIGURAÇÃO DA USART
	; Configura baud rate
	
	.equ baud = 9600
	.equ ubrr_value = int((CLOCK / (16 * baud)) - 1)

	ldi temp, high(ubrr_value)
	sts UBRR0H, temp
	ldi temp, low(ubrr_value)
	sts UBRR0L, temp

	; Habilita TX
	ldi temp, (1<<TXEN0)
	sts UCSR0B, temp

	; Modo assíncrono, 8 bits, 1 stop, sem paridade
	ldi temp, (1<<UCSZ01) | (1<<UCSZ00)
	sts UCSR0C, temp

	;iniciar no estado e2
	ldi timer, 10
	ldi state, 2

	sei
	
main:
	
	;enviando os bits do led para dezenas
	mov temp, count_d
	ori temp, display1; 0b00100000 - display 1
	out PORTC, temp
	rcall delay_small

	;enviando os bits do led para unidades
	mov temp, count_u
	ori temp, display2; 0b00010000 - display 2
	out PORTC, temp
	rcall delay_small

	;timer = registrador responsável pelo tempo em relação a troca dos estados
	;mov timer, count_d
	
	cpi timer, 0b00000000 ; 0
	breq state_one

	cpi timer, 0b00001010 ; 10
	breq state_two

	cpi timer, 0b00100000 ; 32
	breq state_three

	cpi timer, 0b00100100 ; 36
	breq state_four

	cpi timer, 0b01100001 ; 97
	breq state_five

	cpi timer, 0b01100101 ; 101
	breq state_six

	cpi timer, 0b01111111 ; 127
	breq state_seven

	cpi timer, 0b10000011 ; 131
	breq clear

	rjmp main
		
	state_one:
		ldi temp, 0b10010000
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp

		inc state

		; transmite o estado pela UART
		ldi r24, 'H'
		rcall uart_transmit

		rjmp main

	state_two:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00100001
		out PORTB, temp

		ldi count_u, 0b00000111 ; timer unidade = 7
		ldi count_d, 0b00001000 ;  timer dezena = 8

		inc state
		
		; transmite o estado pela UART
		mov r24, state
		rcall uart_transmit

		rjmp main

	state_three:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00100010
		out PORTB, temp

		inc state
		; transmite o estado pela UART
		ldi r24, 'L'
		rcall uart_transmit

		rjmp main

	state_four:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00001100
		out PORTB, temp

		inc state

		rjmp main

	state_five:
		ldi temp, 0b01010000
		out PORTD, temp

		ldi temp, 0b00010100
		out PORTB, temp
		
		ldi count_u, 0b00000100 ; =4
		ldi count_d, 0b00000000

		inc state
		
		rjmp main

	state_six:
		ldi temp, 0b10000100
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp

		ldi count_u, 0b00000000
		ldi count_d, 0b00000100 ; = 4

		inc state

		rjmp main

	state_seven:
		ldi temp, 0b10001000
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp

		inc state

		rjmp main

	clear:
		ldi timer, 0x00
		ldi state, 0x00

	rjmp main


OCI1A_Interrupt:
	push temp
	in temp, SREG
	push temp

	;conta cada segundo para o estado
	inc timer

	;contar unidade
	dec count_u

	;comparar quando a unidade chegar em '10'
	cpi count_u, 0xff
	brne skip

	; zerar unidades
	ldi count_u, 0x09

	;contar dezenas
	dec count_d

	;comparar quando a unidade chegar em '10'
	cpi count_d, 0xff
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

.def byte_tx = r24
uart_transmit:
    lds temp, UCSR0A
    sbrs temp, UDRE0        ; espera até buffer ficar livre
    rjmp uart_transmit
    sts UDR0, byte_tx       ; transmite caractere
    ret
.undef byte_tx

; 20 * 250 = 5000 ciclos
delay_small:
    ldi r24, 20        ; contador externo
outer_loop:
    ldi r25, 250       ; contador interno
inner_loop:
    dec r25            ; decrementa o contador interno
    brne inner_loop    ; repete até zerar
    dec r24            ; quando termina o interno, decrementa o externo
    brne outer_loop
    ret