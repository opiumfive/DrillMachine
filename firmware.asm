/*
 *
 *  Created: 02.10.2012 20:51:08
 *   Author: DeathendAllswell
 */ 
 .equ speed = 0x20
 .equ dist	= 0x06

 .EQU XTAL = 16000000
 .EQU baudrate = 9600  
 .EQU bauddivider = XTAL/(16*baudrate)-1

 .DSEG

 state   : .byte 1
 pred	 : .byte 1
 xa      : .byte 1
 ya      : .byte 1
 ee	     : .byte 2
 holes	 : .byte 100

 .CSEG
 .ORG $000
		RJMP	reset ; 
 .ORG	INT0addr
		RJMP	int_0 ; External Interrupt Request 0
 .ORG	INT1addr
		RJMP	none ; External Interrupt Request 1
 .ORG	 OC2addr
		RJMP	OC2 ; Timer/Counter2 Compare Match
 .ORG	OVF2addr
		RJMP	OVF2 ; Timer/Counter2 Overflow
 .ORG	ICP1addr
		RJMP	none ; Timer/Counter1 Capture Event
 .ORG	OC1Aaddr
		RJMP	none ; Timer/Counter1 Compare Match A
 .ORG	OC1Baddr
		RJMP	none ; Timer/Counter1 Compare Match B
 .ORG	OVF1addr
		RJMP	none ; Timer/Counter1 Overflow
 .ORG	OVF0addr
		RJMP	none ; Timer/Counter0 Overflow
 .ORG	SPIaddr
		RJMP	none ; Serial Transfer Complete
 .ORG	URXCaddr
		RJMP	rx_ok ; USART, Rx Complete
 .ORG	UDREaddr
		RJMP	none ; USART Data Register Empty
 .ORG	UTXCaddr
		RJMP	none ; USART, Tx Complete
 .ORG	ADCCaddr
		RJMP	adc_ok ; ADC Conversion Complete
 .ORG	ERDYaddr
		RJMP	none ; EEPROM Ready
 .ORG	ACIaddr
		RJMP	none ; Analog Comparator
 .ORG	TWIaddr
		RJMP	none ; 2-wire Serial Interface
 .ORG	SPMRaddr
		RJMP	none ; Store Program Memory Ready
 .ORG	INT_VECTORS_SIZE ; $013

 OC2:	IN		R17, PORTD
		ANDI	R17, ~(1<<3)
		OUT		PORTD, R17
		RETI

 ovf2:  PUSH	R17
		IN		R17,SREG
		PUSH	R17
		IN		R17, PORTD
		ORI		R17, (1<<3)
		OUT		PORTD, R17
		POP		R17
		OUT		SREG,R17
		POP		R17
		RETI

rx_ok:	PUSH	R22
		
		PUSH	R16
		IN		R16,SREG
		PUSH	R16
		IN		R23, UDR
		LDS		R22, state
		CPI		R22,'f'
		BRNE	hhkl
		CPI		R23, 'e'
		BRNE	hhkl 
		LDI		R22, 0x00
		STS		ee,R22
		LDI		R22, 0
		STS		ee+1,R22
		LDI		R22, 'x'
		sts		state, R22
		LDI		ZL, low(holes)
		LDI		ZH, high(holes)			
		RJMP	preend
hhkl:	CPI		R22, 'm'
		BREQ	preend
		CPI		R22, 'a'
		BRNE	m1
		CPI		R23, 'd'
		BRNE	nxt
		LDI		R22, 0x00
		STS		ee,R22
		LDI		R22, 0
		STS		ee+1,R22
		LDI		R22, 'h'
		STS		state, R22
		LDI		ZL, low(holes)
		LDI		ZH, high(holes)	
		RJMP	preend	
nxt:	CPI		R23, 'w'
		BREQ	preend
		CPI		R23, 't'
		BRNE	end
		LDI		R22, 'r'
		STS		state, R22
		RJMP	preend
m1:		CPI		R22, 'r'
		BRNE	preend
		ST		Z+, R23
		CPI		R23, 0
		BRNE	end
		LDI		R22, 'l'
		sts		state, R22
		RCALL	laser
preend:	MOV		R16,R22
		RCALL	uart_snt
end:	POP		R16
		OUT		SREG,R16
		POP		R16
		
		POP		R22
		RETI

adc_ok: IN		R25, ADCL
		IN		R25, ADCH
		RETI

int_0:	PUSH	R16
		IN		R16,SREG
		PUSH	R16
		LDS		R16, state
		CPI		R16,'a'
		BREQ	t6
		CPI		R16,'m'
		BREQ	t7
		RJMP	g10

t6:		LDI		R16,'m'
		STS		state, R16
		RCALL	uart_snt
		RCALL	beep
		RCALL	green
		RJMP	g10

t7:		LDI		R16,'a'
		STS		state, R16
		RCALL	uart_snt
		RCALL	beep
		RCALL	blue
g10:	POP		R16
		OUT		SREG,R16
		POP		R16
		RETI




 none:	RETI
;========================entry point=============================
reset:	CLR		R1
		OUT		SREG, R1 
;========================stack init=====================
		LDI		R16, Low(RAMEND)
		OUT		SPL, R16 
		LDI		R16, High(RAMEND)
		OUT		SPH, R16 

;========================clear RAM=============================
		LDI		ZL, Low(SRAM_START)
		LDI		ZH, High(SRAM_START)
clear:	ST		Z+,R1
		CPI		ZH,High(RAMEND)
		BRNE	clear
		CPI		ZL,Low(RAMEND)
		BRNE	clear
;========================init UART======================
		LDI 	R16, low(bauddivider)  
		OUT 	UBRRL,R16
		LDI 	R16, high(bauddivider)
		OUT 	UBRRH,R16
 
		LDI 	R16,0
		OUT 	UCSRA, R16

		LDI 	R16, (1<<RXEN)|(1<<TXEN)|(1<<RXCIE)|(0<<TXCIE)|(0<<UDRIE)
		OUT 	UCSRB, R16	

		LDI 	R16, (1<<URSEL)|(3<<UCSZ0)
		OUT 	UCSRC, R16
;========================i/o ports init===================

		LDI		R16,0x01
		OUT		PORTC,R16
		LDI		R16,0x04
		OUT		PORTD,R16

		LDI		R16, 0xf8 
		OUT		DDRD,R16
		LDI		R16, 0x3F
		OUT		DDRB,R16
		LDI		R16, 0x1E
		OUT		DDRC,R16

;========================timers init===============
		LDI		R16, (1<<TOIE2)|(1<<OCIE2)
		OUT		TIMSK, R16
		LDI		R16, 0x15
		OUT		OCR2, R16
		LDI		R16, (1<<CS22)|(1<<CS21)|(1<<CS20)
		OUT		TCCR2, R16

;========================ADC init====================
		LDI		R16, (1<<ADEN)|(1<<ADIE)|(1<<ADSC)|(1<<ADFR)|(7<<ADPS0)
		OUT		ADCSRA,R16
		LDI		R16,0b01100101
		OUT		ADMUX,R16

;========================init outer interrups=====
		LDI		R16, (1<<ISC01)|(0<<ISC00)
		OUT		MCUCR,R16
		LDI		R16, (1<<INT0)
		OUT		GICR,R16
					
;========================main programm===================	
		RCALL	blue
		LDI		R16, 'a'
		STS		state, R16
		RCALL	uart_snt
		LDI		R16, 0
		STS		xa, R16
		STS		ya, R16
		LDI		ZL, low(holes)
		LDI		ZH, high(holes)
		RCALL	beep
		
		SEI
		
main:	SBIS	PINC, 0
		RJMP	g6
				
		LDS		R16, state
		CPI		R16,'m'
		BREQ	m3
		CPI		R16,'w'
		BREQ	m21
		CPI		R16,'l'
		BREQ	m3
		CPI		R16,'x'
		BREQ	pzg
		CPI		R16,'h'
		BREQ	fre
		RJMP	main

pzg:	LDS		R16, ee
		LDS		R17, ee+1
		LD		R18, Z+
		
eewri:	SBIC	EECR, EEWE
		RJMP	eewri
		OUT 	EEARH, R17
    	OUT 	EEARL, R16
		OUT 	EEDR, R18
		CLI
		SBI 	EECR, EEMWE
		SBI 	EECR, EEWE
		SEI
		SUBI	R16,(-1)
		SBCI	R17,(-1)
		STS		ee, R16
		STS		ee+1, R17
		CPI		R18, 0
		BRNE	pzg
		RCALL	beep
		LDI		R16,'a'
		STS		state,R16

		RCALL	uart_snt
		RJMP	main
fre:	LDS		R16, ee
		LDS		R17, ee+1
fre1:	SBIC	EECR,EEWE
		RJMP	fre1
		OUT 	EEARH, R17
    	OUT 	EEARL, R16
		SBI		EECR, EERE
		IN		R18,EEDR
		ST		Z+, R18
		SUBI	R16,(-1)
		SBCI	R17,(-1)
		STS		ee, R16
		STS		ee+1, R17	
		CPI		R18,0
		BRNE	fre
		LDI		R16,'l'
		RCALL	uart_snt
		STS		state, R16
		RCALL	laser
		RJMP	main

m21:	RJMP	m2	
		
m3:		MOV		R26, R25

		CPI		R26, 0x14
		BRCC	g1
		RCALL	dxr
		LDI		R29,0x01
		STS		pred, R29
		RJMP	main

g1:		CPI		R26, 0x38
		BRCC	g2
		RCALL	dyr
		LDI		R29,0x02
		STS		pred, R29
		RJMP	main

		reset1: RCALL	blue
		LDI		R16,'f'
		STS		state, R16
		RCALL	uart_snt
		RJMP	main



g2:		CPI		R26,0x52
		BRCC	g3
		RCALL	dxl
		LDI		R29,0x03
		STS		pred, R29
		RJMP	main



main1:	RJMP	main
g3:		CPI		R26,0x67
		BRCC	g4
		RCALL	dyl
		LDI		R29,0x04
		STS		pred, R29
		RJMP	main

g4:		CPI		R26,0x79
		BRCC	opp
		LDS		R29,pred
		CPI		R29,0x05
		BREQ	main1
		RCALL	drill
		RCALL	updown
		RCALL	delay
		RCALL	updown
		RCALL	drill
		LDI		R29,0x05
		STS		pred, R29
		RJMP	main

opp:	LDI		R29,0x06
		STS		pred, R29
		RJMP	main

g6:		CPI		R16,'f'
		BRNE	gt
		LDI		R16, 'l'
		sts		state, R16
		RCALL	uart_snt
		RCALL	laser
		RJMP	main
gt:		CPI		R16,'l'
		BRNE	main1
		RCALL	laser
		LDI		R16,'w'
		STS		state, R16
		RCALL	uart_snt
		RCALL	beep
		RCALL	red
		LDI		ZL, low(holes)
		LDI		ZH, high(holes)
		RJMP	main
m2:		LD		R27,Z+
		CPI		R27,0
		BREQ	reset1
		LD		R22,Z+
		LDS		R24, xa
		LDS		R26, ya
		
next1:	CP		R24,R27
		BRCS	rightx
		BREQ	next2
		RCALL	dxl
		DEC		R24
		RJMP	next1
rightx:	RCALL	dxr
		INC		R24
		RJMP 	next1
next2:	CP		R26,R22
		BRCS	forwy
		BREQ	next3
		RCALL	dyl
		DEC		R26
		RJMP	next2
forwy:	RCALL	dyr
		INC		R26
		RJMP 	next2
next3:	STS		xa, R24
		STS		ya, R26
		RCALL	drill
		RCALL	updown
		RCALL	updown
		RCALL	drill
		LDI		R16,'1'
		RCALL	uart_snt
		RJMP	m2
	
		RJMP	main

;========================subprogramms=============================
delay:	PUSH	R16
		PUSH	R17
		PUSH	R18
	
		CLR		R16
		CLR		R17
		CLR		R18
loop:	SUBI	R16,(-1)
		SBCI	R17,(-1)
		SBCI	R18,(-1)
		CPI		R18, 0x2F
		BRNE	loop
		POP		R18
		POP		R17
		POP		R16
		RET

uart_snt:	
		SBIS 	UCSRA,UDRE	
		RJMP	uart_snt 	
		OUT		UDR, R16	
		RET	

updown: PUSH	R18
		PUSH	R19
		PUSH	R20
		PUSH	R21
		IN		R18, OCR2
		CPI		R18, 0x15
		BRNE	up
down:	DEC		R18
		CPI		R18,0x10
		BRNE	del
		OUT		OCR2, R18
		RJMP	ENDD
del:	OUT		OCR2, R18
		CLR		R19
		CLR		R20
		CLR		R21
loop1:	SUBI	R19,(-1)
		SBCI	R20,(-1)
		SBCI	R21,(-1)
		CPI		R21, 0x04
		BRNE	loop1
		RJMP	down
up:		INC		R18
		CPI		R18,0x15
		BRNE	del1
		OUT		OCR2, R18
		RJMP	ENDD
del1:	OUT		OCR2, R18
		CLR		R19
		CLR		R20
		CLR		R21
loop2:	SUBI	R19,(-1)
		SBCI	R20,(-1)
		SBCI	R21,(-1)
		CPI		R21, 0x04
		BRNE	loop2
		RJMP	up
ENDD:	POP		R21
		POP		R20
		POP		R19
		POP		R18
		RET

beep:	PUSH R19
		PUSH R20
		PUSH R21
		PUSH R22
		SEI
		CLR		R19
loop4:	CLR		R20
		CLR		R21
loop3:	SUBI	R20,(-1)
		SBCI	R21,(-1)
		CPI		R21, 0x03
		BRNE	loop3
		IN		R22,PORTB
		LDI		R18,0x01
		EOR		R22,R18
		OUT		PORTB,R22
		INC		R19
		CPI		R19, 0xff
		BRNE	loop4
		POP		R22
		POP		R21
		POP		R20
		POP		R19
		RET

dxl:	PUSH	R18
		PUSH	R19
		PUSH	R20
		PUSH	R21
		CLR		R20
		
loop9:	IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x02
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop5:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop5

		IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x04
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop6:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop6

		IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x08
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop7:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop7

		IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x10
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop8:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop8

		INC		R20
		CPI		R20, dist
		BRNE	loop9
		
		POP		R21
		POP		R20
		POP		R19
		POP		R18
		RET

dxr:	PUSH	R18
		PUSH	R19
		PUSH	R20
		PUSH	R21
		CLR		R20
		
loop10:	IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x10
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop11:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop11

		IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x08
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop12:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop12

		IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x04
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop13:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop13

		IN		R18, PORTC
		ANDI	R18, 0xE1
		ORI		R18, 0x02
		OUT		PORTC, R18

		CLR		R19
		CLR		R21
loop14:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop14

		INC		R20
		CPI		R20, dist
		BRNE	loop10

		POP		R21
		POP		R20
		POP		R19
		POP		R18
		RET

dyl:	PUSH	R18
		PUSH	R19
		PUSH	R20
		PUSH	R21
		CLR		R20
		
loop15:	IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x04
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop16:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop16

		IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x08
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop17:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop17

		IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x10
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop18:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop18

		IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x20
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop19:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop19

		INC		R20
		CPI		R20, dist
		BRNE	loop15
		
		POP		R21
		POP		R20
		POP		R19
		POP		R18
		RET

dyr:	PUSH	R18
		PUSH	R19
		PUSH	R20
		PUSH	R21
		CLR		R20
		
loop20:	IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x20
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop21:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop21

		IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x10
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop22:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop22

		IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x08
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop23:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21,speed
		BRNE	loop23

		IN		R18, PORTB
		ANDI	R18, 0xC3
		ORI		R18, 0x04
		OUT		PORTB, R18

		CLR		R19
		CLR		R21
loop24:	SUBI	R19,(-1)
		SBCI	R21,(-1)
		CPI		R21, speed
		BRNE	loop24

		INC		R20
		CPI		R20, dist
		BRNE	loop20

		POP		R21
		POP		R20
		POP		R19
		POP		R18
		RET

drill:	PUSH	R19
		PUSH	R20
		IN		R19, PORTD
		LDI		R20, (1<<4)
		EOR		R19, R20
		OUT		PORTD, R19
		POP		R20
		POP		R19
		RET

laser:	PUSH	R19
		PUSH	R20
		IN		R19, PORTB
		LDI		R20, (1<<1)
		EOR		R19, R20
		OUT		PORTB, R19
		POP		R20
		POP		R19
		RET

green:	PUSH	R19
		IN		R19,PORTD
		ANDI	R19,0x1F
		ORI		R19,0x80
		OUT		PORTD,R19
		POP		R19
		RET

blue:	PUSH	R19
		IN		R19,PORTD
		ANDI	R19,0x1F
		ORI		R19,0x40
		OUT		PORTD,R19
		POP		R19
		RET

red:	PUSH	R19
		IN		R19,PORTD
		ANDI	R19,0x1F
		ORI		R19,0x20
		OUT		PORTD,R19
		POP		R19
		RET


