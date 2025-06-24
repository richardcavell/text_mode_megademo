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

* DEBUG_MODE means you press T to toggle frame-by-frame mode.
* In frame-by-frame mode, you press F to see the next frame

DEBUG_MODE	EQU	0

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

****************************************
* Display message using operating system
****************************************

	lda	#15
	leax	startup_message, PCR
	lbsr	display_message
	bra	pluck

startup_message:

	FCB	$8f
	FCB	$8f
	FCV	"PRESS"
	FCB	$8f			; blank space
	FCV	"SPACE"
	FCB	$8f
	FCV	"TO"
	FCB	$8f
	FCV	"SKIP"
	FCB	$8f
	FCV	"ANY"
	FCB	$8f
	FCV	"PART"
	FCB	0			; A zero ends the message

***********************************************************
* Pluck routine - make characters disappear from the screen
***********************************************************

TEXTBUF		EQU	$400		; We're not double-buffering
TEXTBUFSIZE	EQU	$200		; so there's only one text screen

pluck:

; First, count the number of characters on each line of the screen

	ldx	#TEXTBUF
	leay	line_counts, PCR	; There are 16 of these

_count_chars_on_one_line:
	ldb	#32			; There are 32 characters per line

_test_char:
	lda	,x+
	cmpa	#$60			; Is it an empty green box?
	beq	_space_char		; Yes

	inc	,y			; No, so count another
					; non-space character
_space_char:
	decb
	bne	_test_char

	cmpx	#TEXTBUF+TEXTBUFSIZE
	beq	_count_chars_end

	leay	1,y			; Start counting the next line
	bra	_count_chars_on_one_line

line_counts:
	RZB 16				; 16 zeroes
line_counts_end:

_count_chars_end:

; Now, check to see if the screen is empty yet

_check_text_screen_empty:
	leay	line_counts, PCR

_test_line:
	tst	,y+
	bne	_not_empty
	cmpy	#line_counts_end
	bne	_test_line

	bra	screen_is_empty	; Go to the next piece of this demo

_not_empty:

; Screen is not empty

_choose_line:
	lbsr	get_random 	; Get a random number in D
	andb	#0b00001111	; Make the random number between 0 and 15

	leay	line_counts, PCR

	tst	b,y		; If there are no more characters on this line
	beq	_choose_line	; choose a different one

	dec	b,y		; There'll be one less character now

	lda	#32
	mul 			; Multiply b by 32 and put the answer in D

	ldx	#TEXTBUF+32	; Make X point to the end of the line
	leax	d,x		; that we will pluck from

	lda	#$60		; Green box (space)

_find_non_space:
	cmpa	,-x		; Go backwards until we find a non-space
	beq	_find_non_space

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

_pluck_loop:
	pshs	b,x
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	bne	empty_the_screen

	lda	#$60
	sta	,x+		; Replace it with a space

	pshs	b, x
	tfr	x,d
	andb	#0b00011111	; Is the address divisible by 32?
	puls	b, x
	bne	_not_divisible

	pshs	b, x
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b, x
	tsta
	bne	empty_the_screen

	bra	_check_text_screen_empty
				; Yes, then we have reached the right
				; side of the screen, so start another pluck

_not_divisible:
	stb	,x		; Put the character one position to the right
	bra	_pluck_loop

empty_the_screen:
	lbsr	clear_screen

screen_is_empty:
	bra	title_screen

**************
* Title screen
**************

title_screen:
	lda	#0
	ldb	#0
	leax	title_screen_graphic, PCR
	lbsr	display_text_graphic
	bra	display_text

; This graphic was made by Microsoft Copilot and modified by me

title_screen_graphic:
	FCV	"(\\/)",0
	FCV	"(O-O)",0
	FCV	"/> >\\",0
	FCB	255

title_screen_text:
	FCB	5, 6
	FCN	"RJFC"	; Each string ends with a zero when you use FCN
	FCB	8, 10
	FCN	"PRESENTS"
	FCB	12, 12
	FCC	"TEXT"
	FCB	$8F
	FCC	"MODE"
	FCB	$8F
	FCC	"DEMO"
	FCB	0
	FCB	255		; The end

display_text:
	leay	title_screen_text, PCR

_print_text_loop:
	lda	,y+
	ldb	,y+
	tfr	y,x

	pshs	y
	lbsr	text_appears
	puls	y
	tsta
	bne	skip_title_screen

_find_zero:
	tst	,y+
	bne	_find_zero

	lda	#255			; This marks the end of the text
					;   lines
	cmpa	,y			; Is that what we have?
	bne	_print_text_loop	; If not, then print the next line
					; If yes, then fall through to the
					;   next section

	ldx	#rjfc_presents_tmd_sound	; Start of sound
	ldy	#rjfc_presents_tmd_sound_end	; End of sound
	lda	#8
	lbsr	play_sound		; Play the sound

	lda	#5
	ldb	#0
	lbsr	encase_text		; "Encase" the three text items
	tsta
	bne	skip_title_screen

	lda	#8
	ldb	#1
	lbsr	encase_text
	tsta
	bne	skip_title_screen

	lda	#12
	ldb	#0
	lbsr	encase_text
	tsta
	bne	skip_title_screen

	lda	#5
	ldb	#3
	lbsr	flash_text_white
	tsta
	bne	skip_title_screen

	lda	#8
	ldb	#3
	lbsr	flash_text_white
	tsta
	bne	skip_title_screen

	lda	#12
	ldb	#3
	lbsr	flash_text_white
	tsta
	bne	skip_title_screen

	lbsr	flash_screen
	tsta
	bne	skip_title_screen
	lbsr	flash_screen
	tsta
	bne	skip_title_screen
	lbsr	flash_screen
	tsta
	bne	skip_title_screen

* Drop the lines off the bottom end of the screen

	lda	#11
	lbsr	drop_screen_content
	tsta
	bne	skip_title_screen

	lda	#7
	lbsr	drop_screen_content
	tsta
	bne	skip_title_screen

	lda	#4
	lbsr	drop_screen_content
	bra	screen_is_clear

skip_title_screen:		; If space was pressed
	lbsr	clear_screen	; Just clear the screen

screen_is_clear:
	bra	loading_screen

loading_screen:
	lda	#0
	ldb	#0
	leax	ascii_art_cat, PCR
	lbsr	display_text_graphic

	leax	loading_text, PCR
	lda	#15
	ldb	#11
	lbsr	text_appears		; Ignore the return value

	lbsr	wait_for_vblank_and_check_for_skip
					; Display it for one frame
	tsta
	bne	_part_1_end

	lda	#15
	ldb	#3
	lbsr	flash_text_white	; Ignore the return value

* This is the end of part 1!
_part_1_end:

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
	FCV	"      : -   '  \\",0
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
	sty	decb_irq_service_routine, PCR	; We will call it at the end
						; of our own handler

	leax	irq_service_routine, PCR
	stx	IRQ_HANDLER		; Our own interrupt service routine
					; is installed

	bsr	switch_on_irq		; Switch IRQ interrupts back on

	rts

uninstall_irq_service_routine:

	bsr	switch_off_irq

	ldy	decb_irq_service_routine, PCR
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
	sta	vblank_happened, PCR

		; In the interests of making our IRQ handler run fast,
		; the routine assumes that decb_irq_service_routine
		; has been correctly initialized

	jmp	[decb_irq_service_routine, PCR]

decb_irq_service_routine:
	RZB	2

vblank_happened:
	RZB	1

****************************************
* Wait for VBlank and check for skip
*
* Inputs: None
* Output:
* A = zero if user is not trying to skip
* A = non-zero if user is trying to skip
****************************************

POLCAT	EQU	$A000

wait_for_vblank_and_check_for_skip:

	clr	vblank_happened, PCR

_wait_for_vblank_and_check_for_skip_loop:

	jsr	[POLCAT]
	cmpa	#' '			; Space bar
	beq	_wait_for_vblank_skip
	cmpa	#3			; Break key
	beq	_wait_for_vblank_skip
	lda	#DEBUG_MODE
	beq	_no_debug_mode

	cmpa	#'T'
	beq	_skip_invert_toggle

	com	debug_mode_toggle, PCR

_skip_invert_toggle:
	ldb	debug_mode_toggle, PCR
	beq	_toggle_is_off

	cmpa	#'F'
	bne	_wait_for_vblank_and_check_for_skip_loop

_toggle_is_off:
_no_debug_mode:
	tst	vblank_happened, PCR
	beq	_wait_for_vblank_and_check_for_skip_loop

	clra		; A VBlank happened
	rts

_wait_for_vblank_skip:
	lda	#1	; User wants to skip
	rts

debug_mode_toggle:

	RZB	1

*****************************************************
* Display a message on the screen
*
* Inputs:
* A = line to put it on
* X = string containing the message (ended by a zero)
*
* Outputs: None
*****************************************************

display_message:

	ldb	#32
	mul
	tfr	x,y	; Y = message
	ldx	#TEXTBUF
	leax	d,x

_display_message_loop:
	lda	,y+
	beq	_display_message_finished
	sta	,x+
	bra	_display_message_loop

_display_message_finished:
	rts

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

	ldd	SEED, PCR
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

	lbsr	switch_on_irq_and_firq

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

************************************************
* Brings text onto the screen using an animation
* X = string to print
* A = line number (0 to 15)
* B = character position (0 to 31)
*
* Outputs:
* A = 0 Everything is okay
* A = non-zero Space was pressed
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
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x,u
	tsta
	beq	_skip
	rts			; Just return a

_skip:
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

	stx	test_area,PCR
	lda	#0b00011111
	anda	test_area+1,PCR	; Is the character position divisible by 32?

	bne	buff_box	; If no, then go back and do it again

	clra			; Space was not pressed
	rts			; Return to the main code

test_area:
	RZB	2

*************************************
* Encases text on the screen
* A = line number
* B = direction (0 = right, 1 = left)
*
* Outputs:
* A = 0 Everything is okay
* A = non-zero User wants to skip
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
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	_no_skip_encase
	rts			; Simply return a

_no_skip_encase:
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

	lbsr	wait_for_vblank_and_check_for_skip	; The final showing
	rts			; we are finished. Return a

encase_right:
	tfr	d,y
	tfr	x,d
	andb	#0b00011111	; If X is evenly divisible
	tfr	y,d
	bne	encase_text_loop	;   by 32, then

	lbsr	wait_for_vblank_and_check_for_skip	; The final showing
	rts			; we are finished

**************************************
* Flashes text with white (buff) boxes
*
* Inputs:
* A = line number (0 to 15)
* B = number of times to flash
**************************************

flash_text_white:
	decb			; We test at the bottom
	pshs	b

	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x		; X = starting position

	leay	flash_text_storage, PCR

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
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	skip_flash_chars
	rts

skip_flash_chars:
	pshs	b,x
	bsr	restore_chars
	puls	b,x

	pshs	b,x
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	skip_flash_chars_2
	rts

skip_flash_chars_2:
	tstb			; We do this routine b times
	beq	flash_finished

	decb
	bra	flash_chars_loop

flash_finished:
	clra
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

	clra
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

	clra
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

	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	skip_flash_screen_copy
	rts

skip_flash_screen_copy:
	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_skip_flash_screen_5

_skip_flash_screen_5:
	ldx	#TEXTBUF
	ldd	#$cfcf

flash_screen_white_loop:
	std	,x++			; Make the whole screen buff color
	std	,x++
	std	,x++
	std	,x++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	flash_screen_white_loop

	lbsr	wait_for_vblank_and_check_for_skip	; If space was pressed
	tsta
	beq	skip_flash_screen_2
	rts				; return to caller

skip_flash_screen_2:
	lbsr	wait_for_vblank_and_check_for_skip	; If space was pressed
	tsta
	beq	skip_flash_screen_3
	rts				; return to caller

skip_flash_screen_3:
	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_skip_flash_screen_4
	rts

_skip_flash_screen_4
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

	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	skip_flash_screen_4
	rts

skip_flash_screen_4:
	lbsr	wait_for_vblank_and_check_for_skip

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
	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	skip_drop_screen
	leas	1,s
	rts

skip_drop_screen:
	puls	a

skip_drop_screen_2:
	puls	a

	pshs	a
	puls	a

	inca				; Next time, start a line lower

	cmpa	#16			; until the starting position is off
					; the screen
	bne	drop_screen_content
	clra
	rts

drop_line:
	cmpa	#15
	blo	do_drop

	clra
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

	clra
	rts

clear_line:
	cmpa	#16
	blo	do_clear

	clra
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

	clra
	rts

**************************
*******************
* Output a graphic
*
* Inputs:
* A = Line number
* B = Column number
* X = Graphic data
*******************

display_text_graphic:
	tfr	x,y

	pshs	b
	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x
	puls	b
	leax	b,x

_display_text_graphic_loop:
        lda     ,y+
        beq     _text_graphic_new_line
        cmpa    #255
        beq	_display_text_graphic_finished
        sta     ,x+
        bra     _display_text_graphic_loop

_text_graphic_new_line:
	tfr	d,u		; Save register b
        tfr     x,d
        andb    #0b11100000
        addd    #32
        tfr     d,x
	tfr	u,d		; Get b back
	leax	b,x
	bra	_display_text_graphic_loop

_display_text_graphic_finished:
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
