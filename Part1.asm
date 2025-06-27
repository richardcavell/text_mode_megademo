* This is Part 1 of Text Mode Demo
* by Richard Cavell
* June 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This demo part is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by a number of authors. You can see it here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
* Part of this code was written by Sean Conner.
* The ASCII art is by Microsoft Copilot, and from asciiart.eu

* DEBUG_MODE means you press T to toggle frame-by-frame mode.
* In frame-by-frame mode, you press F to see the next frame.
* Also, the lower right corner character cycles when the interrupt request
* service routine operates.

DEBUG_MODE	EQU	0

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

**********************
* Zero the DP register
**********************

	jsr	zero_dp_register

*************************
* Install our IRQ handler
*************************

	jsr	install_irq_service_routine

*************************
* Turn off the disk motor
*************************

	jsr	turn_off_disk_motor

******************************
* Turn on 6-bit audio circuits
******************************

	jsr	turn_6bit_audio_on

*************************
* Text buffer information
*************************

TEXTBUF		EQU	$400		; We're not double-buffering
TEXTBUFSIZE	EQU	$200		; so there's only one text screen
TEXTBUFEND	EQU	(TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE	EQU	32
TEXT_LINES	EQU	16

*************************************************************
* Display "space to skip" message at the bottom of the screen
*************************************************************

	lda	#TEXT_LINES-1		; Bottom line of the screen
	ldx	#skip_message
	jsr	display_message
	bra	pluck

skip_message:

	FCV	"  PRESS SPACE TO SKIP ANY PART  "
	FCB	0

***********************************************************
* Pluck routine - make characters disappear from the screen
***********************************************************

pluck:

PLUCK_LINES	EQU	(TEXT_LINES-1)	; The bottom line of
					; the screen is for
					; our skip message

GREEN_BOX	EQU	($60)
WHITE_BOX	EQU	($cf)

; First, count the number of characters on each line of the screen

	jsr	pluck_count_chars_per_line
	bra	pluck_loop

pluck_line_counts:
	RZB PLUCK_LINES			; 15 zeroes
pluck_line_counts_end:

; The structure of an entry in plucks_data is:
; phase (1 byte),
; character (1 byte),
; position (2 bytes)

SIMULTANEOUS_PLUCKS	EQU	3

PLUCK_PHASE_NOTHING	EQU	0
PLUCK_PHASE_TURN_WHITE	EQU	1
PLUCK_PHASE_PLAIN	EQU	2
PLUCK_PHASE_PULLING	EQU	3

plucks_data:
	RZB	SIMULTANEOUS_PLUCKS * 4		; Reserve 4 bytes per pluck
plucks_data_end:

pluck_loop:
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	_pluck_skip			; If the user wants to skip,
						; go here

	jsr	pluck_check_empty_screen	; Is the screen empty?
	tsta
	bne	_pluck_finished			; Yes, we are finished

	jsr	pluck_find_a_spare_slot		; Is there a spare slot?
	tsta
	beq	_pluck_do_a_frame		; No, just keep processing

	jsr	pluck_a_char			; Yes, pluck a character

_pluck_do_a_frame:
	jsr	pluck_do_frame			; Do one frame

	bra	pluck_loop

_pluck_skip:

	lbsr	clear_screen
	bra	_pluck_next_section

_pluck_finished:
	lda	#15
	jsr	clear_line			; and fallthrough

_pluck_next_section:				; Screen is empty either way
	lda	#25
	jsr	wait_frames			; Wait 25 frames
	bra	title_screen

**************
* Title screen
**************

title_screen:

	lda	#0
	ldb	#0
	ldx	#title_screen_graphic
	jsr	display_text_graphic

	lda	#1
	sta	creature_blinks			; Set up creature blinks

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
	FCV	"TEXT MODE DEMO" ; FCV places green boxes for spaces
	FCB	0		; So we manually terminate that line
	FCB	255		; The end

display_text:

	ldx	#title_screen_text

	jsr	print_text
	tsta
	bne	skip_title_screen

	ldx	#rjfc_presents_tmd_sound	; Start of sound
	ldy	#rjfc_presents_tmd_sound_end	; End of sound
	lda	#8
	jsr	play_sound		; Play the sound

	lda	#5
	ldb	#0
	jsr	encase_text		; "Encase" the three text items
	tsta
	bne	skip_title_screen

	lda	#8
	ldb	#1
	jsr	encase_text
	tsta
	bne	skip_title_screen

	lda	#12
	ldb	#0
	jsr	encase_text
	tsta
	bne	skip_title_screen

	lda	#5
	ldb	#3
	jsr	flash_text_white
	tsta
	bne	skip_title_screen

	lda	#8
	ldb	#3
	jsr	flash_text_white
	tsta
	bne	skip_title_screen

	lda	#12
	ldb	#3
	jsr	flash_text_white
	tsta
	bne	skip_title_screen

	jsr	flash_screen
	tsta
	bne	skip_title_screen
	jsr	flash_screen
	tsta
	bne	skip_title_screen
	jsr	flash_screen
	tsta
	bne	skip_title_screen

* Drop the lines off the bottom end of the screen

	lda	#11
	jsr	drop_screen_content
	tsta
	bne	skip_title_screen

	lda	#7
	jsr	drop_screen_content
	tsta
	bne	skip_title_screen

	lda	#4
	jsr	drop_screen_content

				; and fallthrough

skip_title_screen:		; If space was pressed
	clr	creature_blinks
	jsr	clear_screen	; Just clear the screen

	lda	#25
	jsr	wait_frames			; Wait 25 frames

						; and fallthrough
loading_screen:
	lda	#0
	ldb	#0
	ldx	#ascii_art_cat
	jsr	display_text_graphic

	ldx	#loading_text
	lda	#15
	ldb	#11
	jsr	text_appears		; Ignore the return value

	jsr	wait_for_vblank_and_check_for_skip
					; Display it for one frame
	tsta
	bne	_part_1_end

	lda	#15
	ldb	#3
	jsr	flash_text_white	; Ignore the return value

* This is the end of part 1!
_part_1_end:

	jsr	uninstall_irq_service_routine

	clra
	rts

* This art is modified by me from the original by Blazej Kozlowski
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
ascii_art_cat_end:

loading_text:
	FCV	"LOADING...",0

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

**********************
* Zero the DP register
**********************

zero_dp_register:

	clra
	tfr	a, dp

	rts

***************************
* Switch IRQ interrupts off
*
* Inputs: None
* Outputs: None
***************************

switch_off_irq:

	orcc	#0b00010000		; Switch off IRQ interrupts

	rts

**************************
* Switch IRQ interrupts on
*
* Inputs: None
* Outputs: None
**************************

switch_on_irq:

	andcc	#0b11101111		; Switch IRQ interrupts back on

	rts

*********************************
* Install our IRQ service routine
*
* Inputs: None
* Outputs: None
*********************************

IRQ_HANDLER	EQU	$10d

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off IRQ interrupts for now

	ldy	IRQ_HANDLER		; Load the current vector into y
	sty	decb_irq_service_routine	; We will call it at the end
						; of our own handler

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine
					; is installed

	bsr	switch_on_irq		; Switch IRQ interrupts back on

	rts

***************************************************
* Our IRQ handler
*
* Make sure decb_irq_service_routine is initialized
***************************************************

irq_service_routine:

	lda	#1
	sta	vblank_happened

	lda	#DEBUG_MODE
	beq	_skip_debug_visual_indication

; For debugging, this provides a visual indication that
; our handler is running

;	inc	TEXTBUFEND-1

_skip_debug_visual_indication:
		; In the interests of making our IRQ handler run fast,
		; the routine assumes that decb_irq_service_routine
		; has been correctly initialized

	jmp	[decb_irq_service_routine]

decb_irq_service_routine:

	RZB	2

*********************
* Turn off disk motor
*
* Inputs: None
* Outputs: None
*********************

DSKREG	EQU	$FF40

turn_off_disk_motor:

	lda	#0
	sta	DSKREG		; Turn off disk motor

	rts

*********************
* Turn 6-bit audio on
*
* Inputs: None
* Outputs: None
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
	ldy	#TEXTBUF
	leay	d,y	; Y = starting point on the screen

_display_message_loop:
	lda	,x+
	beq	_display_message_finished
	sta	,y+
	cmpy	#TEXTBUFEND
	blo	_display_message_loop

_display_message_finished:

	rts

***********************************
* Pluck - Count characters per line
*
* Inputs: None
* Outputs: None
***********************************

pluck_count_chars_per_line:

	ldx	#TEXTBUF
	ldy	#pluck_line_counts	; There are 15 of these

_pluck_count_chars_on_one_line:
	ldb	#COLS_PER_LINE		; There are 32 characters per line

_pluck_test_char:
	lda	,x+
	cmpa	#GREEN_BOX		; Is it an empty green box?
	beq	_pluck_space_char	; Yes, so don't count it

	inc	,y			; No, so count it

_pluck_space_char:
	decb
	bne	_pluck_test_char

	cmpx	#TEXTBUF+(PLUCK_LINES*COLS_PER_LINE)
	beq	_pluck_count_chars_end

	leay	1,y			; Start counting the next line
	bra	_pluck_count_chars_on_one_line

_pluck_count_chars_end:

	rts

*********************************************
* Wait for VBlank and check for skip
*
* Inputs: None
*
* Output:
* A = 0        -> a VBlank happened
* A = non-zero -> user is trying to skip
*********************************************

POLCAT		EQU	$A000

BREAK_KEY	EQU	3

vblank_happened:

	RZB	1

wait_for_vblank_and_check_for_skip:

	clr	vblank_happened

_wait_for_vblank_and_check_for_skip_loop:
	jsr	[POLCAT]
	cmpa	#' '			; Space bar
	beq	_wait_for_vblank_skip
	cmpa	#BREAK_KEY		; Break key
	beq	_wait_for_vblank_skip
	ldb	#DEBUG_MODE
	beq	_wait_for_vblank
	cmpa	#'t'			; T key
	beq	_wait_for_vblank_invert_toggle
	cmpa	#'T'
	beq	_wait_for_vblank_invert_toggle
	ldb	debug_mode_toggle
	beq	_wait_for_vblank

; If toggle is on, require an F to go forward 1 frame

	cmpa	#'f'
	beq	_wait_for_vblank
	cmpa	#'F'
	beq	_wait_for_vblank
	bra	_wait_for_vblank_and_check_for_skip_loop

_wait_for_vblank:
	tst	vblank_happened
	beq	_wait_for_vblank_and_check_for_skip_loop

	clra		; A VBlank happened
	rts

_wait_for_vblank_skip:
	lda	#1	; User wants to skip
	rts

_wait_for_vblank_invert_toggle:
	com	debug_mode_toggle
	bra	_wait_for_vblank

debug_mode_toggle:

	RZB	1

********************
* Pluck - Do a frame
*
* Inputs: None
* Outputs: None
********************

pluck_do_frame:

	ldy	#plucks_data

_pluck_do_each_pluck:
	lda	,y
	ldb	1,y
	ldx	2,y

	pshs	y
	bsr	_pluck_do_one_pluck
	puls	y

	leay	4,y
	cmpy	#plucks_data_end
	blo	_pluck_do_each_pluck

	rts

_pluck_do_one_pluck:
				; A = Phase
				; B = Character
				; X = Screen Position
				; Y = Pluck Data

	cmpa	#PLUCK_PHASE_NOTHING	; you could do testa instead
	bne	_pluck_phase_at_least_1

	rts			; Phase nothing, do nothing

_pluck_phase_at_least_1:

	cmpa	#PLUCK_PHASE_TURN_WHITE
	bne	_pluck_phase_at_least_2
				; We are white
	lda	#PLUCK_PHASE_PLAIN
	sta	,y
	rts

_pluck_phase_at_least_2:

	cmpa	#PLUCK_PHASE_PLAIN
	bne	_pluck_phase_3

				; We are plain
	stb	,x		; Show the plain character

	lda	#PLUCK_PHASE_PULLING	; Go to phase 3
	sta	,y

	rts

_pluck_phase_3:
				; We are pulling
	lda	#GREEN_BOX
	sta	,x+		; Erase the drawn character

	pshs	b,x,y
	tfr	x,d
	andb	#0b00011111	; Is X divisible by 32?
	puls	b,x,y		; Does not affect condition codes
	beq	_pluck_phase_3_ended

	stb	,x		; Draw it in the next column
	stx	2,y		; Update position in plucks_data

	rts

_pluck_phase_3_ended:		; Character has gone off the right side
	lda	#PLUCK_PHASE_NOTHING	; clra
	sta	,y		; Store it

	rts

*****************************************
* Pluck - Find a spare slot
*
* Inputs: None
*
* Outputs:
* A = (Non-zero) there is a spare slot
* X = (If A is non-zero) the slot address
*****************************************

pluck_find_a_spare_slot:

	lda	#SIMULTANEOUS_PLUCKS
	ldx	#plucks_data

_pluck_find_loop:
	ldb	,x
	cmpb	#PLUCK_PHASE_NOTHING	; tstb
	beq	_pluck_find_found_empty

	deca
	beq	_pluck_find_no_empty_slot
	leax	4,x
	bra	_pluck_find_loop

_pluck_find_no_empty_slot:

	ldx	#0
	clra

	rts

_pluck_find_found_empty:

	lda	#1		; We return X as well

	rts

*************************************************
* Pluck - check to see if the screen is empty yet
*
* Inputs: None
*
* Outputs:
* A = 1 if empty
* A = 0 if not empty
*************************************************

pluck_check_empty_screen:

	bsr	pluck_check_empty_slots
	tsta
	beq	_pluck_check_empty_not_empty

	bsr	pluck_check_empty_lines
	rts

_pluck_check_empty_not_empty:
	clra				; Screen is not clear
	rts

************************

pluck_check_empty_slots:

	ldx	#plucks_data

_pluck_check_data:
	lda	,x
	bne	_pluck_check_data_not_empty
	leax	4,x
	cmpx	#plucks_data_end
	bne	_pluck_check_data

	lda	#1
	rts

_pluck_check_data_not_empty:
	clra				; Screen is not clear
	rts

************************

pluck_check_empty_lines:

	ldy	#pluck_line_counts

_pluck_check_empty_test_line:
	tst	,y+
	bne	_pluck_check_empty_line_not_empty
	cmpy	#pluck_line_counts_end
	bne	_pluck_check_empty_test_line

	lda	#1			; Lines are now clear
	rts

_pluck_check_empty_line_not_empty:
	clra				; Lines are not clear
	rts

***************************
* Pluck - Pluck a character
*
* Inputs: None
* Outputs: None
***************************

pluck_a_char:

	bsr	pluck_check_empty_lines
	tsta
	beq	_pluck_char_get_random

	rts			; No more characters left

_pluck_char_get_random:
	bsr	get_random 	; Get a random number in D
	andb	#0b00001111	; Make the random number between 0 and 15
	cmpb	#PLUCK_LINES
	beq	_pluck_char_get_random	; Don't choose line 15

	ldy	#pluck_line_counts

	tst	b,y		; If there are no more characters on this line
	beq	_pluck_char_get_random	; choose a different one

	dec	b,y		; There'll be one less character now

	lda	#COLS_PER_LINE
	mul 			; Multiply b by 32 and put the answer in D

	ldx	#TEXTBUF+COLS_PER_LINE	; Make X point to the end of the line
	leax	d,x		; that we will pluck from

	lda	#GREEN_BOX	; Green box (space)

_pluck_a_char_find_non_space:
	cmpa	,-x		; Go backwards until we find a non-space
	beq	_pluck_a_char_find_non_space

	ldu	#plucks_data+2	; This checks whether the found char is
				; already being plucked
_pluck_a_char_check:
	cmpx	,u
	beq	_pluck_a_char_find_non_space

	leau	4,u
	cmpu	#plucks_data_end
	blo	_pluck_a_char_check

				; X = position of the character we're plucking
	ldb	,x		; B = the character

; Now register with plucks_data

	tfr	x,y
	pshs	b,y
	jsr	pluck_find_a_spare_slot
	tsta
	beq	_pluck_a_char_impossible

	puls	b,y		; B is the character
				; X is the slot
				; Y is the screen position
	lda	#PLUCK_PHASE_TURN_WHITE		; This is our new phase
	sta	,x+		; Store our new phase
	stb	,x+		; the character
	sty	,x		; And where it is

; Now turn it into a white box

	lda	#WHITE_BOX
	sta	,y

; Now play the pluck sound

	ldx	#pluck_sound	; interrupts and everything else
	ldy	#pluck_sound_end ; pause while we're doing this
	lda	#1
	bsr	play_sound	; Play the pluck noise

	rts

_pluck_a_char_impossible:
	bra	_pluck_a_char_impossible	; Should never get here

*****************************
* Wait for a number of frames
*
* Inputs:
* A = number of frames
*****************************

wait_frames:
	pshs	a
	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	puls	a
	bne	_wait_frames_skip

	deca
	bne	wait_frames

	clra	; and fallthrough

_wait_frames_skip:
	lda	#1
	rts

**********************************************************
* Returns a random-ish number from 0...65535
*
* Output:
* D = The random number
**********************************************************

USE_DEEKS_CODE	EQU	0

	IF	(USE_DEEKS_CODE==0)

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

	ENDIF

	IF	(USE_DEEKS_CODE)

; This code was written by Sean Conner (Deek) and slightly modified
; by me in June 2025 during a discussion on Discord

SEED:

	FCB	0xbe
	FCB	0xef

get_random:

	ldd	SEED
	lsra
	rorb
	bcc	get_random_no_feedback
	eora	#$b4
get_random_no_feedback:
	std	SEED
	rts

	ENDIF

***********************************
* Print text
*
* Inputs:
* X = Pointer to data block
*
* Outputs:
* A = (non-zero) User wants to skip
***********************************

print_text:

	tfr	x,y

_print_text_loop:
	lda	,y+
	ldb	,y+
	tfr	y,x

	pshs	y
	bsr	text_appears
	puls	y
	tsta
	beq	_find_zero

	lda	#1			; User has skipped this
	rts

_find_zero:
	tst	,y+
	bne	_find_zero

	lda	#255			; This marks the end of the text
					;   lines
	cmpa	,y			; Is that what we have?
	bne	_print_text_loop	; If not, then print the next line
					; If yes, then fall through
	clra
	rts

******************************************
* Switch IRQ and FIRQ interrupts on or off
*
* Inputs: None
* Outputs: None
******************************************

switch_off_irq_and_firq:

	orcc	#0b01010000	; Switch off IRQ and FIRQ interrupts

	rts

switch_on_irq_and_firq:

	andcc	#0b10101111	; Switch IRQ and FIRQ interrupts back on

	rts

*******************************
* Play a sound sample
*
* Inputs:
* A = The delay between samples
* X = The sound data
* Y = The end of the sound data
*******************************

play_sound:

	pshs	a,x,y
	bsr	switch_off_irq_and_firq
	puls	a,x,y

	pshs	y	; _play_sound uses A, X and 2,S

	bsr	_play_sound

	puls	y

	bsr	switch_on_irq_and_firq

	rts

_play_sound:
	cmpx	2,s			; Compare X with Y

	bne	_play_sound_more	; If we have no more samples, exit

	rts

_play_sound_more:
	ldb	,x+
	stb	AUDIO_PORT

	tfr	a,b

_sound_delay_loop:
	tstb
	beq	_play_sound		; Have we completed the delay?

	decb				; If not, then wait some more

	bra	_sound_delay_loop

******************
* Clear the screen
*
* Inputs: None
*
* Outputs: None
******************

clear_screen:

	ldx	#TEXTBUF
	ldd	#GREEN_BOX << 8 | GREEN_BOX	; Two green boxes

_clear_screen_clear_char:
	std	,x++			; Might as well do 8 bytes at a time
	std	,x++
	std	,x++
	std	,x++

	cmpx	#TEXTBUFEND		; Finish in the lower-right corner
	bne	_clear_screen_clear_char
	rts

*******************
* Clear a line
*
* Inputs:
* A = line to clear
*
* Outputs: None
*******************

clear_line:

	ldx	#TEXTBUF
	ldb	#32
	mul
	leax	d,x

	ldy	#GREEN_BOX << 8 | GREEN_BOX
	lda	#4

_clear_line_loop:
	sty	,x++
	sty	,x++
	sty	,x++
	sty	,x++

	deca
	bne	_clear_line_loop

	rts

************************************************
* Brings text onto the screen using an animation
*
* Inputs:
* A = line number (0 to 15)
* B = character position (0 to 31)
* X = string to print
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

_text_appears_buff_box:
	lda	#WHITE_BOX	; A buff (whiteish) box
	sta	,x		; Put it on the screen

	pshs	b,x,u
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x,u
	tsta			; Has the user chosen to skip?
	beq	_text_appears_keep_going
	rts			; Just return a

_text_appears_keep_going:
	pshs	b,x,u
	bsr	creature_blink	; The creature in the top-left corner
	puls	b,x,u

	tstb			; If non-zero, we are not printing out
	bne	_text_appears_green_box	; yet

	lda	,u+		; Get the next character from the string
	bne	store_char	; And put it on the screen

	leau	-1,u		; It was a zero we retrieved: Repoint U
				; And fall through to using a green box

_text_appears_green_box:
	tstb
	beq	_text_appears_skip_decrement

	decb

_text_appears_skip_decrement:
	lda	#GREEN_BOX	; Put a green box in A

store_char:
	sta	,x+		; Put the relevant character (green box or char) into
				;   the relevant position

	stx	test_area,PCR
	lda	#0b00011111
	anda	test_area+1,PCR	; Is the character position divisible by 32?

	bne	_text_appears_buff_box	; If no, then go back and do it again

	clra			; Space was not pressed
	rts			; Return to the main code

test_area:

	RZB	2

*****************
* Creature blinks
*
* Inputs: None
* Outputs: None
*****************

creature_blinks:

	RZB	1

creature_blink:
	lda	creature_blinks, PCR
	bne	_creature_blink_blinks_on

	rts		; creature is not blinking

_creature_blink_blinks_on:
	ldd	_creature_blink_frames
	addd	#1
	std	_creature_blink_frames

	lda	_creature_blink_is_blinking
	beq	_creature_blink_open_eyes

	ldd	_creature_blink_frames
	cmpd	#5
	blo	_creature_blink_take_no_action

; Open the creature's eyes

	clr	_creature_blink_is_blinking, PCR
	ldd	#0
	std	_creature_blink_frames, PCR

	ldx	#TEXTBUF+32+1
	lda	#'O'
	sta	,x++
	sta	,x

	rts

_creature_blink_open_eyes:

	ldd	_creature_blink_frames
	cmpd	#85
	blo	_creature_blink_take_no_action

; Close the creature's eyes

	lda	#1
	sta	_creature_blink_is_blinking, PCR
	ldd	#0
	std	_creature_blink_frames, PCR

	ldx	#TEXTBUF+32+1
	lda	#'-' + 64
	sta	,x++
	sta	,x

	rts

_creature_blink_take_no_action:
	rts

_creature_blink_is_blinking:
	RZB	1

_creature_blink_frames:
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
	beq	_encase_text_loop

	leax	31,x		; If 1, start on the right side
				; and fallthrough

_encase_text_loop:
	pshs	b,x
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	_encase_no_skip
	rts			; Simply return a

_encase_no_skip:
_encase_text_more:
	pshs	b,x
	bsr	creature_blink
	puls	b,x

	lda	#GREEN_BOX	; Green box (space)

	cmpa	,x		; If x points to a green box...
	bne	_encase_char_found

	lda	#125		; then put a '=' in it

	tstb
	bne	_encase_backwards

	sta	,x+		; and increment
	bra	_encase_finished_storing

_encase_backwards:
	sta	,x
	leax	-1,x		; and decrement

_encase_finished_storing:
	bra	_encase_are_we_done	; Go back and do the next one

_encase_char_found:
	lda	#125		; This is '='
	sta	-32,x		; add '=' above
	sta	32,x		;   and below

	tstb
	bne	_encase_chars_found_backwards

	leax	1,x		; fallthrough
	bra	_encase_are_we_done

_encase_chars_found_backwards:
	leax	-1,x
				; fallthrough
_encase_are_we_done:
	tstb
	beq	_encase_right	; If we're going right

	tfr	d,y
	tfr	x,d
	andb	#0b00011111
	cmpb	#0b00011111	; If X mod 32 == 31
	tfr	y,d
	bne	_encase_text_loop

	lbsr	wait_for_vblank_and_check_for_skip	; The final showing
	rts			; we are finished. Return a

_encase_right:
	tfr	d,y
	tfr	x,d
	andb	#0b00011111	; If X is evenly divisible
	tfr	y,d
	bne	_encase_text_loop	;   by 32, then

	lbsr	wait_for_vblank_and_check_for_skip	; The final showing
	rts			; we are finished. Return a

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

_flash_copy_line:
	ldd	,x++		; Save the whole line
	std	,y++

	cmpy	#flash_text_storage_end
	bne	_flash_copy_line

				; Now the line has been saved,
				; Turn all text to white

	leax	-32,x		; Back to the start of the line

	puls	b

_flash_chars_loop:
	pshs	b,x
	bsr	_flash_chars_white
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	_skip_flash_chars
	rts

_skip_flash_chars:
	pshs	b,x
	bsr	_restore_chars
	lbsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	_skip_flash_chars_2
	rts

_skip_flash_chars_2:
	tstb			; We do this routine b times
	beq	_flash_finished

	decb
	bra	_flash_chars_loop

_flash_finished:
	clra
	rts			; Done, go away now

*********************************
* Turns all chars on a line white
*********************************

_flash_chars_white:

_flash_chars_white_loop:
	lda	,x

	cmpa	#125		; '='
	beq	_flash_chars_not_flashable

	cmpa	#65		; Is it from A to
	blo	_flash_chars_not_flashable
	cmpa	#127		; question mark
	bhi	_flash_chars_not_flashable

	lda	#WHITE_BOX	; a white (buff) box
	sta	,x		; store it, and fall through

_flash_chars_not_flashable:
	leax	1,x
	tfr	x,d
	andb	#0b00011111	; Calculate x mod 32
	bne	_flash_chars_white_loop	; If more, go back

	rts

*****************************************
* Restore the chars from our storage area
*
* Inputs:
* X = pointer to start of the line
*
* Outputs: None
*****************************************

_restore_chars:
	leay	flash_text_storage, PCR

_flash_restore_chars:
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++

	cmpy	#flash_text_storage_end
	bne	_flash_restore_chars

	rts

flash_text_storage:
	RZB	32
flash_text_storage_end:

**************************
* Flashes the screen white
*
* Inputs: None
* Outputs: None
**************************

flash_screen:

	ldx	#TEXTBUF
	leay	flash_screen_storage, PCR

_flash_screen_copy_loop:
	ldd	,x++			; Make a copy of everything
	std	,y++			; on the screen

	cmpx	#TEXTBUF+TEXTBUFSIZE
	blo	_flash_screen_copy_loop

	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_flash_screen_no_skip

	rts

_flash_screen_no_skip:
	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_flash_screen_no_skip_2

	rts

_flash_screen_no_skip_2:
	ldx	#TEXTBUF
	ldd	#WHITE_BOX << 8 | WHITE_BOX

_flash_screen_white_loop:
	std	,x++			; Make the whole screen buff color
	std	,x++
	std	,x++
	std	,x++

	cmpx	#TEXTBUFEND
	bne	_flash_screen_white_loop

	lbsr	wait_for_vblank_and_check_for_skip	; If space was pressed
	tsta
	beq	_skip_flash_screen_2
	rts				; return to caller

_skip_flash_screen_2:
	lbsr	wait_for_vblank_and_check_for_skip	; If space was pressed
	tsta
	beq	_skip_flash_screen_3
	rts				; return to caller

_skip_flash_screen_3:
	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_skip_flash_screen_4
	rts

_skip_flash_screen_4:
	ldx	#TEXTBUF
	leay	flash_screen_storage, PCR

_flash_screen_restore_loop:
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	_flash_screen_restore_loop

	lbsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_flash_screen_skip_5
	rts

_flash_screen_skip_5:
	lbsr	wait_for_vblank_and_check_for_skip
	rts				; Return A

********************************
* Drop screen content
*
* Inputs:
* A = starting line
********************************

drop_screen_content:

	pshs	a
	bsr	_drop_each_line
	tsta
	bne	_skip_drop_each_line
	puls	a

	inca				; Next time, start a line lower

	cmpa	#16			; until the starting position is off
					; the screen
	blo	drop_screen_content

	clra
	rts

_skip_drop_each_line:
	leas	1,s
	rts

_drop_each_line:
	pshs	a
	inca
	inca
	bsr	_drop_line		; Drop the bottom line
	puls	a

	pshs	a
	inca
	bsr	_drop_line		; Drop the middle line
	puls	a

	pshs	a
	bsr	_drop_line		; Drop the top line
	puls	a

	lbsr	clear_line		; Clear the top line

	lbsr	wait_for_vblank_and_check_for_skip
	rts

_drop_line:
	cmpa	#15
	blo	_do_drop

	clra
	rts				; Off the bottom end of the screen


_do_drop:
	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x			; X = pointer to a line of the screen

	ldb	#32

_move_line_down:
	lda	,x			; Retrieve the character
	sta	32,x			; and store it one line below
	leax	1,x

	decb
	bne	_move_line_down

	clra
	rts

_skip_drop_screen:
	lda	#1
	rts

************************
* Display a text graphic
*
* Inputs:
* A = Line number
* B = Column number
* X = Graphic data
************************

display_text_graphic:

	tfr	x,y	; Y = graphic data

	tfr	d,u	; Save B
	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x
	tfr	u,d	; B = column number
	leax	b,x	; X = Screen memory to start at

_display_text_graphic_loop:
        lda     ,y+
        beq     _text_graphic_new_line
        cmpa    #255
        beq	_display_text_graphic_finished
        sta     ,x+
        bra     _display_text_graphic_loop

_text_graphic_new_line:
	tfr	d,u		; Save register B
        tfr     x,d
        andb    #0b11100000
        addd    #32
        tfr     d,x
	tfr	u,d		; Get B back
	leax	b,x
	bra	_display_text_graphic_loop

_display_text_graphic_finished:
	rts

***********************************
* Uninstall our IRQ service routine
*
* Inputs: None
* Outputs: None
***********************************

uninstall_irq_service_routine:

	lbsr	switch_off_irq

	ldy	decb_irq_service_routine, PCR
	sty	IRQ_HANDLER

	lbsr	switch_on_irq

	rts

*************************************
* Here is our raw data for our sounds
*************************************

flash_screen_storage:		; Use the area of memory reserved for
				; the pluck sound, because we're not
				; using it again

pluck_sound:
	INCLUDEBIN "Sounds/Pluck/Pluck.raw"
pluck_sound_end:

rjfc_presents_tmd_sound:
	INCLUDEBIN "Sounds/RJFC_Presents_TMD/RJFC_Presents_TMD.raw"
rjfc_presents_tmd_sound_end:
