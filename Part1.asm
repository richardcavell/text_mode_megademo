* This is Part 1 of Text Mode Demo
* by Richard Cavell
* June 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by other authors. You can see it here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
* Part of this code was written by Ciaran Anscomb
* You can visit his website at https://6809.org.uk

* This starting location is found through experimentation

		ORG $3000

**********************
* Zero the DP register
**********************

	clrb
	tfr	b, dp

*******************
* Check for 64K RAM
*******************

	lbsr	switch_off_irq		; Switch off IRQ interrupts for now
	lbsr	set_sam_ty		; Switch ROM out, upper 32K of RAM in

	; This code was modified from some code written by Ciaran Anscomb

	lda	$0062
	ldb	$8063
	coma
	comb
	std	$8062
	cmpd	$8062
	bne	ram_not_found
	cmpd	$0062
	beq	ram_not_found

	; End code written by Ciaran Anscomb

	lbsr	clear_sam_ty		; Switch upper 32K RAM out, ROM in
	lbsr	switch_on_irq		; Switch IRQ interrupts back on
	bra	ram_check_end

ram_not_found:
	lbsr	clear_sam_ty
	lbsr	switch_on_irq

	ldx	#ram_error_message
	lbsr	display_message

	lda	#$01
	rts				; Return to the operating system

ram_error_message:
	FCV	"YOU"
	FCB	$8f			; blank space
	FCV	"NEED"
	FCB	$8f
	FCB	54			; '6'
	FCB	52			; '4'
	FCV	"K"
	FCB	$8f
	FCV	"RAM"
	FCB	$8f
	FCV	"FOR"
	FCB	$8f
	FCV	"THIS"
	FCB	$8f
	FCV	"DEMO"
	FCB	$22			; A quotation mark ends the error message

ram_check_end:

*************************
* Install our IRQ handler
*************************

	lbsr	install_irq_service_routine

*************************
* Turn off the disk motor
*************************

	lbsr	turn_off_disk_motor

******************************
* Turn on 6-bit audio circuits
******************************

	lbsr	turn_6bit_audio_on

***********************************************************
* Pluck routine - make characters disappear from the screen
***********************************************************

TEXTBUF		EQU	$400		; We're not double-buffering
TEXTBUFSIZE	EQU	$200		; so there's only one text screen

; First, count the number of characters on each line of the screen

	ldx	#TEXTBUF
	ldy	#line_counts		; There are 16 of these

count_chars_on_one_line:
	ldb	#32			; There are 32 characters per line

test_char:
	lda	,x+
	cmpa	#$60			; Is it a space?
	beq	space_char

	inc	,y			; Count another non-space character

space_char:
	decb
	bne	test_char

	cmpx	#TEXTBUF+TEXTBUFSIZE
	beq	count_chars_end

	leay	1,y			; Start counting the next line
	bra	count_chars_on_one_line

line_counts:
	RZB 16			; 16 zeroes
line_counts_end:

count_chars_end:

; Now, check to see if the screen is empty yet

check_text_screen_empty:
	ldy	#line_counts

test_line:
	tst	,y+
	bne	not_empty
	cmpy	#line_counts_end
	bne	test_line

empty:
	bra	screen_is_empty	; Go to the next piece of this demo

not_empty:

choose_line:
	lbsr	get_random 	; Get a random number in D
	ldy	#line_counts

	clra
	andb	#0b00001111	; Make it between 0 and 15

	tst	b,y		; If there are no more characters on this line
	beq	choose_line	; choose a different one

	dec	b,y		; There'll be one less character now

	lda	#32
	mul 			; Multiply b by 32 and put the answer in D

	ldx	#TEXTBUF+32	; Make X point to the end of the line
	leax	d,x		; that we will pluck from

	lda	#$60		; Green box (space)

find_non_space:
	cmpa	,-x		; Go backwards until we find a non-space
	beq	find_non_space

				; X = position of the character we're plucking
	ldb	,x		; B = the character

	pshs	b,x
	ldx	#pluck_sound
	ldd	#(pluck_sound_end-pluck_sound)
	lbsr	play_sound			; Play the pluck noise
	puls	b,x

POLCAT	EQU	$A000		; ROM routine

pluck_loop:
	jsr	[POLCAT]	; Is the spacebar being pressed?
	cmpa	#' '
	bne	do_pluck	; No, then pluck the character

	lbsr	clr		; Yes, then clear the screen
	bra	screen_is_empty	; And go to the next part

do_pluck:
	lbsr	wait_for_vblank	; This is how we time

	lda	#$60
	sta	,x+		; Replace it with a space

	tfr	d,y		; Save the character in the lower byte of Y
	tfr	x,d
	andb	#0b00011111	; Is the address divisible by 32?

	beq	check_text_screen_empty	; Yes, then we have reached the right side
				; of the screen, so start another pluck

move_character:
	tfr	y,d		; Get the character being saved back in B

	stb	,x		; Put the character one position to the right
	bra	pluck_loop

screen_is_empty:

**************
* Title screen
**************
title_screen:
	ldy #title_screen_text

print_text_loop:
	lda ,y+
	ldb ,y+
	tfr y,x

	pshs y
	lbsr text_appears
	puls y

find_zero:
	tst ,y+
	bne find_zero

	lda #255		; This marks the end of the text lines
	cmpa ,y			; Is that what we have?
	bne print_text_loop	; If not, then print the next line
				; If yes, then fall through to the next section

end:
	bra end
	rts

title_screen_text:
	FCB 5, 6
	FCN "RJFC"	; Each string ends with a zero when you use FCN
	FCB 8, 10
	FCN "PRESENTS"
	FCB 12, 12
	FCC "TEXT"
	FCB $8F
	FCC "MODE"
	FCB $8F
	FCC "DEMO"
	FCB 0
	FCB 255		; The end

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

*********************************
* Switch IRQ interrupts on or off
*********************************

switch_off_irq:

	orcc	#0b00010000	; Switch off IRQ interrupts
	rts

switch_on_irq:

	andcc	#0b11101111	; Switch IRQ interrupts back on
	rts

******************************************
* Switch IRQ and FIRQ interrupts on or off
******************************************

switch_off_irq_and_firq:

	orcc	#0b01010000	; Switch off IRQ and FIRQ interrupts
	rts

switch_on_irq_and_firq:

	andcc	#0b10101111	; Switch IRQ and FIRQ interrupts back on
	rts

*********************
* Turn off disk motor
*********************

DSKREG	EQU	$FF40

turn_off_disk_motor:

	clr	DSKREG		; Turn off disk motor
	rts

**********************************
* Switch SAM TY register on or off
**********************************

SAM_TY_SET	EQU	$FFDF
SAM_TY_CLEAR	EQU	$FFDE

set_sam_ty:

	lda	#$ff
	sta	SAM_TY_SET	; Switch ROM out, upper 32K of RAM in
	rts

clear_sam_ty:

	lda	#$00
	sta	SAM_TY_CLEAR	; Switch upper 32K of RAM out, ROM back in
	rts

************************************************************
* Display a message using the operating system
*
* Input:
* X = string containing the message (ended by double quotes)
************************************************************

DISPL		EQU	$B99C

display_message:

	clr	$6F			; Output to the screen
	leax	-1,x			; The first character is skipped over
	JSR	DISPL			; Put the string to the screen
	rts

*********************************
* Install our IRQ service routine
*********************************

IRQ_HANDLER	EQU	$10d

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off interrupts for now

	ldy	IRQ_HANDLER			; Load the current vector into y
	sty	decb_irq_service_routine	; We will call it at the end of our own handler

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine is installed

	bsr	switch_on_irq		; Switch interrupts back on

	rts

**********************
* Our IRQ handler
**********************

vblank_happened:
	FCB	0

irq_service_routine:
	lda	#1
	sta	vblank_happened

					; In the interests of making our IRQ handler run fast,
					; the routine assumes that decb_irq_service_routine
					; has been correctly initialized

	jmp	[decb_irq_service_routine]

decb_irq_service_routine:
	RZB 2

*********************
* Turn 6-bit audio on
*********************

AUDIO_PORT  	EQU	$FF20		; (the top 6 bits)
DDRA		EQU	$FF20
PIA2_CRA	EQU	$FF21
AUDIO_PORT_ON	EQU	$FF23		; Port Enable Audio (bit 3)

turn_6bit_audio_on:

* This code was modified from code written by Trey Tomes

	lda	AUDIO_PORT_ON
	ora	#0b00001000
	sta	AUDIO_PORT_ON	; Turn on 6-bit audio

* End code modified from code written by Trey Tomes

* This code was written by other people (see the top of this file)

	ldb	PIA2_CRA
	andb	#0b11111011
	stb	PIA2_CRA

	lda	#0b11111100
	sta	DDRA

	orb	#0b00000100
	stb	PIA2_CRA

* End of code written by other people

	rts

**********************************************************
* Returns a random-ish number from 0...65535
*
* Output:
* D = the random number
**********************************************************

SEED:
	FCB	0xBE
	FCB	0xEF

get_random:
	ldd	SEED
	mul
	addd	#3037
	std	SEED
	rts

*************************
* Play a sound sample
*
* Inputs:
* X = The sound data
* D = The length in bytes
*************************

play_sound:
	bsr	switch_off_irq_and_firq

	tfr	d, y

send_value:
	cmpy	#0
	beq	send_values_finished	; If we have no data, exit

	tfr	y,d
	andb	#0b00000011		; Get the last two bits
	beq	send_values		; If they're both 0, start doing it
					;  4 samples at a time

	lda	,x+
	sta	AUDIO_PORT
	leay	-1,y

	bra	send_value

send_values:			; Go 4 samples at a time

	lda	,x+
	sta	AUDIO_PORT	; Poke the raw sound data into the Audio Port
	lda	,x+
	sta	AUDIO_PORT	; Poke the raw sound data into the Audio Port
	lda	,x+
	sta	AUDIO_PORT	; Poke the raw sound data into the Audio Port
	lda	,x+
	sta	AUDIO_PORT	; Poke the raw sound data into the Audio Port

	leay	-4,y
	bne	send_values

send_values_finished:

	lbsr	switch_on_irq_and_firq

	rts

******************
* Clear the screen
******************

clr:
	ldx	#TEXTBUF
	ldd	#$6060			; Two green boxes

clear_char:
	std	,x+			; Might as well do 8 bytes at a time
	std	,x+
	std	,x+
	std	,x+

	cmpx	#TEXTBUF+TEXTBUFSIZE	; Finish in the lower-right corner
	bne	clear_char
	rts

*****************
* Wait for VBlank
*****************

wait_for_vblank:
	clr	vblank_happened		; Put a zero in vblank_happened

wait_loop:
	tst	vblank_happened		; As soon as a 1 appears...
	beq	wait_loop

	rts				; ...return to caller

* Brings text onto the screen using an animation
* X = string to print
* A = line number (0 to 15)
* B = character position (0 to 31)

text_appears:
	tfr x,u			; U = string to print
	pshs b
	ldy #TEXTBUF
	ldb #32
	mul
	leax d,y		; X is where to start the animation
	puls b			; B is the character position to start
				;   printing the string

buff_box:
	lda #$cf		; A buff box
	sta ,x			; Put it on the screen

	pshs b,x,u
	bsr wait_for_vblank
	puls b,x,u

	tstb			; If non-zero, we are not printing out
	bne green_box		; yet

	lda ,u+			; Get the next character from the string
	bne store_char		; And put it on the screen

	leau -1,u		; It was a zero we retrieved: Repoint U
				; And fall through to using a green box

green_box:
	tstb
	beq skip_decrement

	decb

skip_decrement:
	lda #$60		; Put a green box in A

store_char:
	sta ,x+			; Put the relevant character (green box or char) into
				;   the relevant position

	stx  test_area
	lda  #0b11111
	anda test_area+1	; Is the character position divisible by 32?

	bne buff_box		; If no, then go back and do it again
	rts

test_area:
	RZB 2

pluck_sound:
	INCLUDEBIN "Pluck.raw"
pluck_sound_end:

* We have two text buffers, to enable double buffering
* Memory locations 1024-1535 and 1536-2047
TEXTBUF2	EQU	1536

