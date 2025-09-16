
;configurar a porta  c para ser output
.def temp = r16
; carrega no registrador
ldi temp, $FF
; joga o valor no ddrc
out DDRC, temp

;leds
;definir porta D como saida
out DDRD, temp;define a direção da portaD, define como saida (11111111)
;porta do semaforo 3 e 4
out PORTD, temp;envia o valor
 
out DDRB, temp
out PORTB, temp

; manda para a porta c
out PORTC, temp
; definir a porta c para informar qual numero sera definido
; liga primeiro a4 e depois a5 (transistors)
;ligar o a4
.equ display1 = 0b00010000 ;quinto bit settado 1 
.equ display2 = 0b00100000
; 4 primeiros bits de temp settados como 1 and 0b0001000
ldi temp, ($ff >> 4) | display1 ; 0b00011111

out PORTC, temp



lp:
	ldi temp, ($ff >> 4) | display1 ; 0b00011111
	out PORTC, temp
	;delay

	ldi temp, ($ff >> 4) | display2 ; 0b00011111
	out PORTC, temp
	rjmp lp
	
