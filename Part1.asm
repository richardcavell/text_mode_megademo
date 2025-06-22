* This is Part 1 of Text Mode Demo
* by Richard Cavell
* June 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This code is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by other authors. You can see it here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

**********************
* Zero the DP register
**********************

	clra
	tfr	a, dp

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
	leay	line_counts,PCR		; There are 16 of these

count_chars_on_one_line:
	ldb	#32			; There are 32 characters per line

test_char:
	lda	,x+
	cmpa	#$60			; Is it an empty green box?
	beq	space_char		; Yes

	inc	,y			; No, so count another
					; non-space character
space_char:
	decb
	bne	test_char

	cmpx	#TEXTBUF+TEXTBUFSIZE
	beq	count_chars_end

	leay	1,y			; Start counting the next line
	bra	count_chars_on_one_line

line_counts:
	RZB 16				; 16 zeroes
line_counts_end:

count_chars_end:

; Now, check to see if the screen is empty yet

check_text_screen_empty:
	leay	line_counts,PCR

test_line:
	tst	,y+
	bne	not_empty
	cmpy	#line_counts_end
	bne	test_line

	bra	screen_is_empty	; Go to the next piece of this demo

not_empty:

choose_line:
	lbsr	get_random 	; Get a random number in D
	leay	line_counts,PCR

	andb	#0b00001111	; Make the random number between 0 and 15

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

	lda	#$cf		; Blink it white for the duration of our sound
	sta	,x

	pshs	b,x		; We don't have time to check for space while
	ldx	#pluck_sound	; playing the sound
	ldy	#pluck_sound_end
	lda	#1
	lbsr	play_sound	; Play the pluck noise
	puls	b,x

pluck_loop:
	pshs	b,x
	lbsr	check_for_space
	puls	b,x
	tsta
	bne	empty_the_screen

do_pluck:
	pshs	b,x
	lbsr	wait_for_vblank	; This is how we time
	puls	b,x

	lda	#$60
	sta	,x+		; Replace it with a space

	tfr	d,y		; Save the character in the lower byte of Y
	tfr	x,d
	andb	#0b00011111	; Is the address divisible by 32?

	beq	check_text_screen_empty	; Yes, then we have reached the right
				; side of the screen, so start another pluck

move_character:
	tfr	y,d		; Get the character being saved back in B

	stb	,x		; Put the character one position to the right
	bra	pluck_loop

empty_the_screen:
	lbsr	clear_screen

screen_is_empty:
	bra	title_screen

**************
* Title screen
**************

title_screen:
	leay	title_screen_text,PCR

print_text_loop:
	lda	,y+
	ldb	,y+
	tfr	y,x

	pshs	y
	lbsr	text_appears
	puls	y
	tsta
	bne	skip_title_screen

find_zero:
	tst	,y+
	bne	find_zero

	lda	#255			; This marks the end of the text
					;   lines
	cmpa	,y			; Is that what we have?
	bne	print_text_loop		; If not, then print the next line
					; If yes, then fall through to the
					;   next section

	ldx	#rjfc_presents_tmd_sound	; Start of sound
	ldy	#rjfc_presents_tmd_sound_end	; End of sound
	lda	#8
	lbsr	play_sound		; Play the sound

	lda	#5
	ldb	#0
	lbsr	encase_text		; "Encase" the three text items

	lda	#8
	ldb	#1
	lbsr	encase_text

	lda	#12
	ldb	#0
	lbsr	encase_text

	lda	#5
	ldb	#3
	lbsr	flash_text_white

	lda	#8
	ldb	#3
	lbsr	flash_text_white

	lda	#12
	ldb	#3
	lbsr	flash_text_white

	lbsr	flash_screen
	lbsr	flash_screen
	lbsr	flash_screen

* Drop the lines off the bottom end of the screen

	lda	#11
	lbsr	drop_screen_content

	lda	#7
	lbsr	drop_screen_content

	lda	#4
	lbsr	drop_screen_content

skip_title_screen:		; If space was pressed
	lbsr	clear_screen	; Just clear the screen
	bra	loading_screen

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

loading_screen:
	ldx	#ascii_art_cat
	lbsr	output_full_screen

	ldx	#loading_text
	lda	#15
	ldb	#11
	lbsr	text_appears

	lda	#15
	ldb	#3
	lbsr	flash_text_white

* This is the end of part 1!

	lbsr	uninstall_irq_service_routine

	clra
	rts

* This art is modified from the original by Blazej Kozlowski
* It's from https://www.asciiart.eu/animals/cats

ascii_art_cat:
	FCV	"      .",0
	FCV	"      \\'*-.",0
	FCV	"       )  .'-.",0
	FCV	"      .  : '. .",0
	FCV	"      : .   '  \\",0
	FCV	"      ; *' ..   '*-..",0
	FCV	"      '-.-'          '-.",0
	FCV	"        ;       '       '.",0
	FCV	"        :.       .        \\",0
	FCV	"        . \\  .   :   .-'   .",0
	FCV	"        '  '+.;  ;  '      :",0
	FCV	"        :  '  I    ;       ;-.",0
	FCV	"        ; '   : :'-:     ..'* ;",0
	FCV	"[BUG].*' /  .*' ; .*'- +'  '*'",0
	FCV	"     '*-*   '*-*  '*-*'",0
	FCB	255
ascii_art1_end:

loading_text:
	FCV	"LOADING...",0

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

*********************************
* Install our IRQ service routine
*********************************

IRQ_HANDLER	EQU	$10d

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off IRQ interrupts for now

	ldy	IRQ_HANDLER		; Load the current vector into y
	sty	decb_irq_service_routine	; We will call it at the end of our own handler

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine is installed

	bsr	switch_on_irq		; Switch IRQ interrupts back on

	rts

uninstall_irq_service_routine:

	bsr	switch_off_irq

	ldy	decb_irq_service_routine
	sty	IRQ_HANDLER

	bsr	switch_on_irq

	rts

*********************************
* Switch IRQ interrupts on or off
*********************************

switch_off_irq:

	orcc	#0b00010000		; Switch off IRQ interrupts
	rts

switch_on_irq:

	andcc	#0b11101111		; Switch IRQ interrupts back on
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

**********************
* Our IRQ handler
**********************

irq_service_routine:
	lda	#1
	sta	vblank_happened

		; In the interests of making our IRQ handler run fast,
		; the routine assumes that decb_irq_service_routine
		; has been correctly initialized

	jmp	[decb_irq_service_routine]

decb_irq_service_routine:
	RZB 2

vblank_happened:
	FCB	0

*****************
* Wait for VBlank
*****************

wait_for_vblank:
	clr	vblank_happened		; Put a zero in vblank_happened

wait_loop:
	tst	vblank_happened		; As soon as a 1 appears...
	beq	wait_loop

	rts				; ...return to caller

**********************************************************
* Returns a random-ish number from 0...65535
*
* Output:
* D = the random number
**********************************************************

* I found these values through simple experimentation.
* This RNG could be improved on.

SEED:
	FCB	0xBE
	FCB	0xEF

get_random:
	ldd	SEED
	mul
	addd	#3037
	std	SEED
	rts

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

*******************************
* Play a sound sample
*
* Inputs:
* X = The sound data
* Y = The end of the sound data
* A = The delay between samples
*******************************

play_sound:
	bsr	switch_off_irq_and_firq

	pshs	y

send_value:
	cmpx	,s			; Compare X with Y

	beq	send_values_finished	; If we have no more samples, exit

	ldb	,x+
	stb	AUDIO_PORT

	tfr	a,b

sound_delay_loop:
	tstb
	beq	send_value		; Have we completed the delay?

	decb				; If not, then wait some more
	bra	sound_delay_loop

send_values_finished:

	puls	y

	bsr	switch_on_irq_and_firq

	rts

******************
* Clear the screen
******************

clear_screen:
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

********************************************************
* Is space bar being pressed?
*
* Outputs:
* A = 0 if space bar is not pressed
* A = non-zero if space bar is being pressed
********************************************************

POLCAT	EQU	$A000			; ROM routine

check_for_space:
	jsr	[POLCAT]		; A ROM routine
	cmpa	#' '
	beq	skip
	clra
	rts

skip:
	lda	#1
	rts

************************************************
* Brings text onto the screen using an animation
* X = string to print
* A = line number (0 to 15)
* B = character position (0 to 31)
************************************************

text_appears:
	tfr	x,u		; U = string to print
	pshs	b
	ldy	#TEXTBUF
	ldb	#32
	mul
	leax	d,y		; X is where to start the animation
	puls	b		; B is the character position to start
				;   printing the string

buff_box:
	lda	#$cf		; A buff box
	sta	,x		; Put it on the screen

	pshs	b,x,u
	bsr	check_for_space	; Space bar skips this section
	puls	b,x,u
	tsta
	lbne	#skip_title_screen

	pshs	b,x,u
	lbsr	wait_for_vblank
	puls	b,x,u

	tstb			; If non-zero, we are not printing out
	bne	green_box	; yet

	lda	,u+		; Get the next character from the string
	bne	store_char	; And put it on the screen

	leau	-1,u		; It was a zero we retrieved: Repoint U
				; And fall through to using a green box

green_box:
	tstb
	beq	skip_decrement

	decb

skip_decrement:
	lda	#$60		; Put a green box in A

store_char:
	sta	,x+		; Put the relevant character (green box or char) into
				;   the relevant position

	stx	test_area
	lda	#0b11111
	anda	test_area+1	; Is the character position divisible by 32?

	bne	buff_box	; If no, then go back and do it again
	rts

test_area:
	RZB	2

*************************************
* Encases text on the screen
* A = line number
* B = direction (0 = right, 1 = left)
*************************************

encase_text:
	tfr	d,y		; Y (lower 8 bits) is direction

	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x		; X is our starting position

	tfr	y,d		; B is direction
	tstb			; If 0, start on the left side
	beq	encase_text_loop

	leax	31,x		; If 1, start on the right side
				; and fallthrough

encase_text_loop:
	pshs	b,x
	bsr	check_for_space	; Space bar exits this
	puls	b,x
	tsta
	lbne	skip_title_screen

	pshs	b,x
	lbsr	wait_for_vblank	; Start on the next frame
	puls	b,x

encase_text_more:
	lda	#$60		; Green box (space)

	cmpa	,x		; If x points to a green box...
	bne	encase_char_found

	lda	#125		; then put a '=' in it

	tstb
	bne	encase_backwards

	sta	,x+		; and increment
	bra	encase_finished_storing

encase_backwards:
	sta	,x
	leax	-1,x		; and decrement

encase_finished_storing:
	bra	encase_are_we_done	; Go back and do the next one

encase_char_found:
	lda	#125		; This is '='
	sta	-32,x		; add '=' above
	sta	32,x		;   and below

	tstb
	bne	encase_chars_found_backwards

	leax	1,x		; fallthrough
	bra	encase_are_we_done

encase_chars_found_backwards:
	leax	-1,x
				; fallthrough
encase_are_we_done:
	tstb
	beq	encase_right	; If we're going right

	tfr	d,y
	tfr	x,d
	andb	#0b00011111
	cmpb	#0b00011111	; If X mod 32 == 31
	tfr	y,d
	bne	encase_text_loop
	rts

encase_right:
	tfr	d,y
	tfr	x,d
	andb	#0b00011111	; If X is evenly divisible
	tfr	y,d
	bne	encase_text_loop	;   by 32, then

	rts			; we are finished

**************************************
* Flashes text with white (buff) boxes
*
* Inputs:
* A = line number (0 to 15)
* B = number of times to flash
**************************************

flash_text_white:
	pshs	b

	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x		; X = starting position

	ldy	#flash_text_storage

flash_copy_line:
	ldd	,x++		; Save the whole line
	std	,y++

	cmpy	#flash_text_storage_end
	bne	flash_copy_line

				; Now the line has been saved,
				; Turn all text to white

	leax	-32,x		; Back to the start of the line

	puls	b

flash_chars_loop:
	pshs	b,x
	bsr	flash_chars_white
	puls	b,x

	pshs	b,x
	lbsr	check_for_space
	puls	b,x
	tsta
	lbne	skip_title_screen

	pshs	b,x
	lbsr	wait_for_vblank
	puls	b,x

	pshs	b,x
	bsr	restore_chars
	puls	b,x

	pshs	b,x
	lbsr	check_for_space
	puls	b,x
	tsta
	lbne	skip_title_screen

	pshs	b,x
	lbsr	wait_for_vblank
	puls	b,x

	tstb			; We do this routine b times
	beq	flash_finished

	decb
	bra	flash_chars_loop

flash_finished:
	rts			; Done, go away now

*********************************
* Turns all chars on a line white
*********************************

flash_chars_white:
	lda	,x

	cmpa	#125		; '='
	beq	not_flashable

	cmpa	#65		; Is it from A to
	blo	not_flashable
	cmpa	#127		; Question mark
	bhi	not_flashable

	lda	#$cf		; a buff box
	sta	,x		; store it, and fall through

not_flashable:
	leax	1,x
	tfr	x,d
	andb	#0b00011111	; Calculate x mod 32
	bne	flash_chars_white	; If more, go back

	rts

*****************************************
* Restore the chars from our storage area
*
* Inputs:
* X = pointer to start of the line
*****************************************

restore_chars:
	ldy	#flash_text_storage

flash_restore_chars:
	ldd	,y++
	std	,x++

	cmpy	#flash_text_storage_end
	bne	flash_restore_chars

	rts

flash_text_storage:
	RZB	32
flash_text_storage_end:


**************************
* Flashes the screen white
*
* Inputs:
*   none
**************************

flash_screen:
	ldx	#TEXTBUF
	ldy	#flash_screen_storage

flash_screen_copy_loop:
	ldd	,x++			; Make a copy of everything on the screen
	std	,y++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	flash_screen_copy_loop

	lbsr	check_for_space
	tsta
	lbne	skip_title_screen

	lbsr	wait_for_vblank

	ldx	#TEXTBUF
	ldd	#$cfcf

flash_screen_white_loop:
	std	,x++			; Make the whole screen buff color
	std	,x++
	std	,x++
	std	,x++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	flash_screen_white_loop

	lbsr	check_for_space
	tsta
	lbne	skip_title_screen

	lbsr	wait_for_vblank

	lbsr	check_for_space
	tsta
	lbne	skip_title_screen

	lbsr	wait_for_vblank

	ldx	#TEXTBUF
	ldy	#flash_screen_storage

flash_screen_restore_loop:
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	flash_screen_restore_loop

	lbsr	check_for_space
	tsta
	lbne	skip_title_screen

	lbsr	wait_for_vblank

	lbsr	check_for_space
	tsta
	lbne	skip_title_screen

	lbsr	wait_for_vblank

	rts

********************************
* Drop screen content
*
* Inputs:
* A = starting line
********************************

drop_screen_content:
	pshs	a
	inca
	inca
	bsr	drop_line		; Drop the bottom line
	puls	a

	pshs	a
	inca
	bsr	drop_line		; Drop the middle line
	puls	a

	pshs	a
	bsr	drop_line		; Drop the top line
	puls	a

	pshs	a
	bsr	clear_line		; Clear the top line
	puls	a


	pshs	a
	lbsr	check_for_space
	tsta
	puls	a
	lbne	skip_title_screen

	pshs	a
	lbsr	wait_for_vblank
	puls	a

	pshs	a
	lbsr	check_for_space
	tsta
	puls	a
	lbne	skip_title_screen

	pshs	a
	lbsr	wait_for_vblank
	puls	a

	inca				; Next time, start a line lower

	cmpa	#16			; until the starting position is off
					; the screen
	bne	drop_screen_content
	rts

drop_line:
	cmpa	#15
	blo	do_drop

	rts				; Off the bottom end of the screen

do_drop:
	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x			; X = pointer to a line of the screen

	ldb	#32

move_line_down:
	lda	,x			; Retrieve the character
	sta	32,x			; and store it one line below
	leax	1,x

	decb
	bne	move_line_down

	rts

clear_line:
	cmpa	#16
	blo	do_clear

	rts				; Off the bottom end

do_clear:
	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x

	ldb	#8

	lda	#$60

clear_loop:
	sta	,x+
	sta	,x+
	sta	,x+
	sta	,x+

	decb
	bne	clear_loop

	rts

**************************************
* Output full screen
*
* Inputs:
* X = the text to be put on the screen
**************************************

output_full_screen:
	tfr	x,y			; Y = beginning of our data
	ldx	#TEXTBUF		; X = beginning of the screen

	tfr	x,u			; U = beginning of the screen

keep_outputting:
	lda	,y+			; What's the next thing to draw?
	cmpa	#255
	beq	output_full_screen_end	; If the end, finish
	tsta				; If it's a character
	bne	output_char		; go and draw it

	leau	32,u			; If 0, go to the next line
	tfr	u,x
	bra	keep_outputting

output_char:
	sta	,x+
	bra	keep_outputting

output_full_screen_end:
	rts

*************************************
* Here is our raw data for our sounds
*************************************

flash_screen_storage:			; Use the area of memory reserved for
					; the pluck sound, because we're not
					; using it again

pluck_sound:
	INCLUDEBIN "Sounds/Pluck/Pluck.raw"
pluck_sound_end:

rjfc_presents_tmd_sound:
	INCLUDEBIN "Sounds/RJFC_Presents_TMD/RJFC_Presents_TMD.raw"
rjfc_presents_tmd_sound_end:
