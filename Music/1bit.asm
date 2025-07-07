;********************************************
; 2 voice squarewave pattern player 
; for 1 bit output at $ff22
; (C) Simon Jonassen (invisible man)
;
; FREE FOR ALL - USE AS YOU SEE FIT, JUST
; REMEBER WHERE IT ORGINATED AND GIVE CREDIT
;********************************************


		opt		6809
		opt		cd
		org		$3f00

;********************************************
;* Main
;********************************************
start		orcc		#$50		;nuke irq/firq
		dec		$71		;force any reset to be cold
;********************************************
; double note values to save shifts
; on the sequencer
;********************************************
		ldx		#zix
convert		ldd		,x
		asla
		aslb	
		std		,x++
		cmpx		#endzix
		blo		convert

dpval		lda		#*/256
		tfr		a,dp
		setdp		dpval


;********************************************
;* 1 bit at $ff22
;********************************************
		lda		$ff23
		anda		#$fb
		sta		$ff23
		
		ldb		$ff22
		orb		#$02
		stb		$ff22

		ora		#$04
		sta		$ff23
		lda		$ff22

;********************************************
; SETUP IRQ ROUTINE
;********************************************
		lda		#$0e		(DP JMP #NOTE)
		ldb		#note&255	DP address of irq
		std		$10c

		lda		$ff03		DISABLE VSYNC VECTORED IRQ
		anda		#$fe
		sta		$ff03
		lda		$ff02		ACK ANY OUTSTANDING VSYNC

		lda		$ff01		ENABLE HSYNC VECTORED IRQ
		ora		#3		3/1 DEPENDS ON EDGE
		sta		$ff01
		lda		$ff00		ACK ANY OUTSTANDING HSYNC
;********************************************
; ENABLE IRQ/FIRQ
;********************************************
		andcc		#$af		;enable irq		

poop		inc		$400
		jmp		poop		; IF YOU WANT BASIC THEN DON'T USE DP !!!
		rts

;********************************************
; PLAYER ROUTINE
;********************************************
note		ldx	counter
		leax	-1,x
		stx	counter
		bne	sum
		ldx	#$100
		stx	counter
;********************************************
; SEQUENCER
;********************************************
		opt	cc
		opt	ct
oldu		ldu	#zix		;save pattern position
curnote		pulu	d		;load 2 notes from pattern
		cmpu	#endzix
		bne	plnote
		ldu	#zix		;start of tune
plnote		stu	oldu+1		;restore pattern position to start
		sta	<frq1+2
		stb	<frq2+2
frq1		ldx	#freqtab	;get the right freq
		ldx	,x
		stx	<freq+1		;store
frq2		ldx	#freqtab
		ldx	,x
		stx	<freq2+1
		lda	$ff00		;ack irq
		rti

		opt	cc
		opt	ct
;********************************************
; NOTE ROUTINE
;********************************************

sum		ldd 	#$0000 
freq		addd 	#$0000
		std 	<sum+1

sum2		ldd	#$0000	
		bcs 	freq2		;tripped on overflow from above summation
		addd	<freq2+1	;add the new freq (ch2)
		std	<sum2+1		;store it
		bcs	bit_on		;carry (overflow on above add)

bit_off		lda	#0		;turn off 1bit
		sta	$ff22		;set the hardware
		lda	$ff00		;ack irq
		rti

freq2		addd	#$0000		;our 1st SUM tripped an overflow
		std	<sum2+1		;and we store back to sum #2
bit_on		lda	#2		;and we set the bit
		sta	$ff22		;set the hardware
		lda	$ff00		;ack irq
		rti


frames		fdb	$0
counter		fdb	$100
		align	$100
;******************************************************
;equal tempered 12 note per octave frequency table
;
; HSYNC/2 (7.875Khz)
;******************************************************


freqtab
;c0	fdb	0,70,75,79,83,88,94,99,105,111,118,125
c1	fdb	0,141,149,158,167,177,188,199,211,223,237,251
c2	fdb	266,282,298,316,335,355,376,398,422,447,474,502			
c3	fdb	532,563,597,632,670,710,752,796,844,894,947,1003	
c4	fdb	1063,1126,1193,1264,1339,1419,1503,1593,1688,1788,1894,2007
c5	fdb	2126,2253,2387,2529,2679,2838,3007,3186,3375,3576,3789,4014
c6	fdb	4252,4505,4773,5057,5358,5676,6014,6371,6750,7152,7577,8028
c7	fdb	8505,9011,9546,10114,10716,11353,12028,12743,13501,14303,15154,16055
c8	fdb	17010,18021,19093,20228,21431,22705,24056,25486,27001,28607,30308,32110



;********************************************
;ONE LONG PATTERN TO SAVE CYCLES OF SEQ
;********************************************
zix	

PAT0
	fcb $35,$2b
	fcb $35,$2b
	fcb $35,$2b
	fcb $0,$0
	fcb $35,$2b
	fcb $35,$2b
	fcb $35,$2b
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $35,$2b
	fcb $35,$2b
	fcb $35,$2b
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $31,$2b
	fcb $31,$2b
	fcb $31,$2b
	fcb $0,$0
	fcb $35,$2b
	fcb $35,$2b
	fcb $35,$2b
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $38,$30
	fcb $38,$30
	fcb $38,$30
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$2c
	fcb $0,$2c
	fcb $0,$2c
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $0,$0
	fcb $31,$29
	fcb $31,$29
	fcb $31,$29


	
endzix	fdb	$ffff	;signal loop

	end	start
	
