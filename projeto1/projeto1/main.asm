; *********************************************** ;
; Projeto 1 - Semaforo com USART				  ;
; Grupo: 										  ;									
; - VICTOR HUGO SILVA ANGELO			 	 	  ;
; - RYAN GOMES TORRES BARBALHO COSTA	 		  ;	
; - RUAN TENORIO DE MELO				 		  ;
; *********************************************** ;

#define CLOCK 16.0e6 // 16.0e6 s
#define DELAY 1 ; 1 micro-segundos

.def temp = r16 ; Registrador temporário
.def count_u = r17 ; Registrador para contar as unidades
.def count_d = r18 ; Registrador para contar as dezenas
.def state = r19 ; Registrador para controlar o estado atuaç
.def timer = r20
.def byte_tx = r21
.def state_sent = r22 ; Flag para indicar se o estado já foi enviado pela USART

; *********************************************** ;
;       Constantes de Ativação dos Displays		  ;										 		  ;
; *********************************************** ;
.equ display1 = 0b00010000 ; Quinto bit enviado na porta C irá ativar o display 1 através do transistor;
.equ display2 = 0b00100000 ; Sexto bit enviado na porta C irá ativar o display 2 através do transistor;

; *********************************************** ;
;    Configurações dos endereços de interrupção	   ;
; *********************************************** ;
.cseg
.org 0x0000 ; Vetor de reset
jmp reset

.org OC1Aaddr ; Vetor de interrupção do Timer1 Compare A
jmp OCI1A_Interrupt

reset:
	; Inicialização do Stack Pointer
    ldi temp, high(RAMEND)
    out SPH, temp
    ldi temp, low(RAMEND)
    out SPL, temp
	
; *********************************************** ;
;            Configurações do Timer1			   ;
; *********************************************** ;

	.equ PRESCALE = 0b101 ; Configuração do Clock Selector para 1024
	.equ PRESCALE_DIV = 1024 ; Valor utilizado do preescale
	
	.equ WGM = 0b0100 ; Configuração do Waveform Generation Mode para CTC (Clear Timer on Compare Match)
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535 ; Garante que o valor de TOP está dentro do intervalo válido para 16 bits
	.error "TOP is out for range"
	.endif

	; Carregamento do TOP
	ldi temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp

	; Configuração dos bits 1 e 0 do WGM no TCCR1A (Lembrando que os bits 2 e 3 estão em outro registrador)
	ldi temp, ((WGM&0b11) << WGM10)
	sts TCCR1A, temp

	; Configuração do WGM2 no TCCR1B e do prescaler
	ldi temp, ((WGM >> 2) << WGM12) | (PRESCALE << CS10)
	sts TCCR1B, temp

	; Habilita a interrupção de Compare Match A do Timer1 para controlar a transição dos estados do semáforo
	ldi temp, (1<<OCIE1A)
	sts TIMSK1, temp

; *********************************************** ;
;      Configurações das Portas Utilizadas   	   ;
; *********************************************** ;
; Configuração dos pinos como saída
	ldi temp, (1 << PCINT8) | (1 << PCINT9) | (1 << PCINT10) | (1 << PCINT11) | (1 << PCINT12) | (1 << PCINT13)
	out DDRC, temp

	; todos os pinos da PORTD (semaforo 3 e 4)
	ldi temp, (1 << PCINT23) | (1 << PCINT22) | (1 << PCINT21) | (1 << PCINT20) | (1 << PCINT19) | (1 << PCINT18)
	out DDRD, temp

	; todos os pinos da temp como sa?da (semaforo 1 e 2)
	ldi temp, (1 << PCINT5) | (1 << PCINT4) | (1 << PCINT3) | (1 << PCINT2) | (1 << PCINT1) | (1 << PCINT0)
	out DDRB, temp

; *********************************************** ;
;      Configurações da USART (9600, 8N1)  	       ;
; *********************************************** ;
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

	; Iniciar no estado e2
	ldi timer, 10
	ldi state, 2

	sei
	
main:
	
	; Envia o valor das dezenas no display 1
	mov temp, count_d ;
	ori temp, display1; ; Une a informação das unidades e o display a ser ativado em um mesmo registrador 0b00100000 - display 1
	out PORTC, temp
	rcall delay_small ; Pequeno delay para conseguir visualizar os dois displays

	; Envia o valor das unidades no display 2 (Lógica semelhante as dezenas)
	mov temp, count_u
	ori temp, display2;
	out PORTC, temp
	rcall delay_small

	; Verifica o estado atual do semáforo e realiza as ações correspondentes
	cpi timer, 0b00000000 ; 0
	brne not_state_one
	jmp state_one

	not_state_one:
		cpi timer, 0b00001010 ; 10
		brne not_state_two
		jmp state_two

	not_state_two:
		cpi timer, 0b00100000 ; 32
		brne not_state_three
		jmp state_three

	not_state_three:
		cpi timer, 0b00100100 ; 36
		brne not_state_four
		jmp state_four

	not_state_four:
		cpi timer, 0b01100001 ; 97
		brne not_state_five
		jmp state_five

	not_state_five:
		cpi timer, 0b01100101 ; 101
		brne not_state_six
		jmp state_six

	not_state_six:
		cpi timer, 0b01111111 ; 127
		brne not_state_seven
		jmp state_seven

	not_state_seven:
		cpi timer, 0b10000011 ; 131
		brne not_clear
		jmp clear

	not_clear:
		jmp main
		
	state_one:
		ldi temp, 0b10010000
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp

		inc state

		; Transmite o estado pela USART
		tst state_sent      ; Já enviou?
		brne skip_usart_one	; Se sim, pula

		ldi ZH, high(state_one_msg << 1)
		ldi ZL, low(state_one_msg << 1)
		rcall usart_send_string ; Chama a rotina de transmissão serial

		ldi state_sent, 1 ; Marca como enviado

		skip_usart_one: jmp main

	state_two:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00100001
		out PORTB, temp

		ldi count_u, 0b00000111 ; timer unidade = 7
		ldi count_d, 0b00001000 ;  timer dezena = 8

		inc state

		; Transmite o estado pela USART
		tst state_sent        
		brne skip_usart_two 

		ldi ZH, high(state_two_msg << 1)
		ldi ZL, low(state_two_msg << 1)
		rcall usart_send_string

		ldi state_sent, 1    

		skip_usart_two:

		jmp main

	state_three:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00100010
		out PORTB, temp

		inc state

		; Transmite o estado pela USART
		tst state_sent      
		brne skip_usart_three

		ldi ZH, high(state_three_msg << 1)
		ldi ZL, low(state_three_msg << 1)
		rcall usart_send_string

		ldi state_sent, 1  

		skip_usart_three:

		jmp main

	state_four:
		ldi temp, 0b00110000
		out PORTD, temp

		ldi temp, 0b00001100
		out PORTB, temp

		inc state

		; Transmite o estado pela USART só 1x
		tst state_sent   
		brne skip_usart_four 

		ldi ZH, high(state_four_msg << 1)
		ldi ZL, low(state_four_msg << 1)
		rcall usart_send_string

		ldi state_sent, 1     ; marca como enviado

		skip_usart_four:

		jmp main

	state_five:
		ldi temp, 0b01010000
		out PORTD, temp

		ldi temp, 0b00010100
		out PORTB, temp
		
		ldi count_u, 0b00000100 ; =4
		ldi count_d, 0b00000000

		inc state

		; Transmite o estado pela USART só 1x
		tst state_sent       
		brne skip_usart_five

		ldi ZH, high(state_five_msg << 1)
		ldi ZL, low(state_five_msg << 1)
		rcall usart_send_string

		ldi state_sent, 1    
		skip_usart_five:

		jmp main

	state_six:
		ldi temp, 0b10000100
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp

		ldi count_u, 0b00000000
		ldi count_d, 0b00000100 ; = 4

		inc state

		; Transmite o estado pela USART
		tst state_sent    
		brne skip_usart_six

		ldi ZH, high(state_six_msg << 1)
		ldi ZL, low(state_six_msg << 1)
		rcall usart_send_string

		ldi state_sent, 1
		
		skip_usart_six:

		jmp main

	state_seven:
		ldi temp, 0b10001000
		out PORTD, temp

		ldi temp, 0b00100100
		out PORTB, temp

		inc state

		; Transmite o estado pela USART só 1x
		tst state_sent 
		brne skip_usart_seven

		ldi ZH, high(state_seven_msg << 1)
		ldi ZL, low(state_seven_msg << 1)
		rcall usart_send_string

		ldi state_sent, 1

		skip_usart_seven:

		jmp main

	clear:
		ldi timer, 0x00
		ldi state, 0x00

	jmp main


OCI1A_Interrupt:
	; Salva o estado dos registradores que serão utilizados na ISR
	push temp
	in temp, SREG
	push temp

	; Conta cada segundo para o estado
	inc timer
	clr state_sent

	; Contar unidade
	dec count_u

	; Comparar quando contador de unidades chega em '10'
	cpi count_u, 0xff
	brne skip ; Se não, não zerar

	; Se sim, zerar unidades
	ldi count_u, 0x09

	; Contar dezenas
	dec count_d

	; Comparar quando a unidade chegar em '10'
	cpi count_d, 0xff
	brne skip

	;zerar dezenas
	ldi count_d, 0x00

	skip:
		pop temp
		out SREG, temp
		pop temp
		reti


; MENSAGENS

state_one_msg: .db "Estado 1: S1 - Vermelho; S2 - Vermelho; S3 - Vermelho; S4 - Vermelho.", 0x0D, 0x0A, 0
state_two_msg: .db "Estado 2: S1 - Vermelho; S2 - Verde; S3 - Verde; S4 - Vermelho.", 0x0D, 0x0A, 0
state_three_msg: .db "Estado 3: S1 - Vermelho; S2 - Amarelo; S3 - Verde; S4 - Vermelho.", 0x0D, 0x0A, 0
state_four_msg: .db "Estado 4: S1 - Verde; S2 - Vermelho; S3 - Verde; S4 - Vermelho.", 0x0D, 0x0A, 0
state_five_msg: .db "Estado 5: S1 - Amarelo; S2 - Vermelho; S3 - Amarelo; S4 - Vermelho.", 0x0D, 0x0A, 0
state_six_msg: .db "Estado 6: S1 - Vermelho; S2 - Vermelho; S3 - Vermelho; S4 - Verde.", 0x0D, 0x0A, 0
state_seven_msg: .db "Estado 7: S1 - Vermelho; S2 - Vermelho; S3 - Vermelho; S4 - Amarelo.", 0x0D, 0x0A, 0

; --- ROTINAS DE TRANSMISS�O USART ---
; usart_send_string: Envia uma string localizada na mem�ria de programa
; Entrada: Ponteiro Z (r31:r30) aponta para o in�cio da string
usart_send_string:
    lpm byte_tx, Z+     ; Carrega byte da mem�ria de programa e incrementa Z
    cpi byte_tx, 0      ; Compara com o terminador nulo
    breq uart_send_string_end ; Se for nulo, termina
    rcall uart_transmit ; Envia o byte
    jmp uart_send_string
usart_send_string_end:
    ret

; usart_transmit: Envia um �nico byte
; Entrada: byte_tx (r21) cont�m o caractere para enviar
usart_transmit:
    lds temp, UCSR0A
    sbrs temp, UDRE0
    jmp uart_transmit
    sts UDR0, byte_tx
    ret

; Delay de 20 * 250 = 5000 ciclos 
delay_small:
    ldi r24, 20        ; contador externo
outer_loop:
    ldi r25, 250       ; contador interno
inner_loop:
    dec r25            ; decrementa o contador interno
    brne inner_loop    ; repete at? zerar
    dec r24            ; quando termina o interno, decrementa o externo
    brne outer_loop
    ret