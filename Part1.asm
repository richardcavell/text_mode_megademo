* This is Part 1 of Text Mode Demo
* by Richard Cavell
* June - July 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This demo part is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by a number of other authors
* You can see here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
* Part of this code was written by Sean Conner (Deek)
* The sound Pop.raw is from Mouth_pop.ogg by Cori from Wikimedia Commons
* https://commons.wikimedia.org/wiki/File:Mouth_pop.ogg
* The sound Type.raw is from Modelm.ogg by Cpuwhiz13 from Wikimedia Commons
* here: https://commons.wikimedia.org/wiki/File:Modelm.ogg
* The ASCII art of the baby elephant is by Shanaka Dias at asciiart.eu

* DEBUG_MODE means you press T to toggle frame-by-frame mode.
* In frame-by-frame mode, you press F to see the next frame.
* Also, you can make the lower right corner character cycle when
* the interrupt request service routine operates.

DEBUG_MODE	EQU	0

* Between each section, wait this number of frames

WAIT_PERIOD	EQU	25

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

	jsr	zero_dp_register		; Zero the DP register
	jsr	install_irq_service_routine	; Install our IRQ handler
	jsr	turn_off_disk_motor		; Silence the disk drive
	jsr	turn_6bit_audio_on		; Turn on the 6-bit DAC

	jsr	display_skip_message
	jsr	pluck_the_screen		; First section
	jsr	joke_startup_screen		; Second section
	jsr	loading_screen			; Third section

	jsr	uninstall_irq_service_routine

	clra
	clrb
	rts		; Return to Disk Extended Color BASIC

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

*********************************
* Install our IRQ service routine
*
* Inputs: None
* Outputs: None
*********************************

IRQ_HANDLER	EQU	$10d

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off IRQ interrupts for now

	ldx	IRQ_HANDLER		; Load the current vector into X
	stx	decb_irq_service_routine	; We will call it at the end
						; of our own handler

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine
					; is installed

	bsr	switch_on_irq		; Switch IRQ interrupts back on

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

	inc	(TEXTBUFEND-1)	; The lower-right corner character cycles

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

	clra
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

*************************
* Text buffer information
*************************

TEXTBUF		EQU	$400		; We're not double-buffering
TEXTBUFSIZE	EQU	$200		; so there's only one text screen
TEXTBUFEND	EQU	(TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE	EQU	32
TEXT_LINES	EQU	16

*********************************************
* Display message at the bottom of the screen
*********************************************

display_skip_message:

	lda	#TEXT_LINES-1		; Bottom line of the screen
	ldx	#skip_message
	bsr	display_message
	rts

skip_message:

	FCV	"  PRESS SPACE TO SKIP ANY PART"
	FCB	0

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

	ldb	#COLS_PER_LINE
	mul
	ldy	#TEXTBUF
	leay	d,y	; Y = starting point on the screen

_display_message_loop:
	cmpy	#TEXTBUFEND
	bhs	_display_message_finished	; End of text buffer
	lda	,x+
	beq	_display_message_finished	; Terminating zero
	sta	,y+
	bra	_display_message_loop

_display_message_finished:
	rts

***************
* Pluck routine
***************

PLUCK_LINES	EQU	(TEXT_LINES-1)	; The bottom line of
					; the screen is for
					; our skip message

GREEN_BOX	EQU	$60
WHITE_BOX	EQU	$cf

pluck_line_counts:
	RZB PLUCK_LINES			; 15 zeroes
pluck_line_counts_end:

; The structure of an entry in plucks_data is:
; phase     (1 byte),
; character (1 byte),
; position  (2 bytes)

MAX_SIMULTANEOUS_PLUCKS	EQU	10

PLUCK_PHASE_NOTHING	EQU	0
PLUCK_PHASE_TURN_WHITE	EQU	1
PLUCK_PHASE_PLAIN	EQU	2
PLUCK_PHASE_PULLING	EQU	3

plucks_data:
	RZB	MAX_SIMULTANEOUS_PLUCKS * 4	; Reserve 4 bytes per pluck
plucks_data_end:

simultaneous_plucks:
	RZB	1

pluck_the_screen:

; First, count the number of characters on each line of the screen

	jsr	pluck_count_chars_per_line

; Second, start the number of simultaneous plucks at 1

	lda	#1
	sta	simultaneous_plucks

_pluck_loop:
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	_pluck_skip			; Does the user wants to skip?

	bsr	count_frames

	jsr	pluck_is_screen_empty		; Is the screen empty?
	tsta
	bne	_pluck_finished			; Yes, we are finished

	jsr	pluck_continue			; No, continue plucking

	bra	_pluck_loop

_pluck_finished:
_pluck_skip:
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

_pluck_count_chars_test_char:
	lda	,x+
	cmpa	#GREEN_BOX		 ; Is it an empty green box?
	beq	_pluck_count_chars_space ; Yes, so don't count it
					 ; or
	inc	,y			 ; No, so count it

_pluck_count_chars_space:
	decb
	bne	_pluck_count_chars_test_char

	cmpx	#(TEXTBUF+PLUCK_LINES*COLS_PER_LINE)
	beq	_pluck_count_chars_end

	leay	1,y			; Start counting the next line
	bra	_pluck_count_chars_on_one_line

_pluck_count_chars_end:

	rts

****************************************
* Wait for VBlank and check for skip
*
* Inputs: None
*
* Output:
* A = 0        -> a VBlank happened
* A = Non-zero -> user is trying to skip
****************************************

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
	ldb	_debug_mode_toggle
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
	com	_debug_mode_toggle
	bra	_wait_for_vblank

_debug_mode_toggle:

	RZB	1

***********************************
* Count frames
*
* Inputs: None
* Outputs: None
***********************************

_pluck_frames:
	RZB	1

count_frames:

	lda	_pluck_frames
	inca
	sta	_pluck_frames			; Keep count of the frames

	cmpa	#50				; Every 50 frames,
	bne	_skip_increase

	clra
	sta	_pluck_frames			; reset the counter, and
	lda	simultaneous_plucks		; increase the number of plucks
	cmpa	#MAX_SIMULTANEOUS_PLUCKS	; happening at the same time
	beq	_skip_increase

	inca
	sta	simultaneous_plucks		; fallthrough to rts

_skip_increase:
	rts

*************************************************
* Pluck - check to see if the screen is empty yet
*
* Inputs: None
*
* Outputs:
* A = (non-zero) if empty
* A = 0 if not empty
*************************************************

pluck_is_screen_empty:

	bsr	pluck_check_empty_slots
	tsta
	beq	_pluck_screen_not_empty

	bsr	pluck_check_empty_lines
	rts

_pluck_screen_not_empty:
	clra				; Screen is not clear
	rts

************************

pluck_check_empty_slots:

	ldx	#plucks_data
	lda	simultaneous_plucks	; Multiply by 4
	lsla
	lsla
	leay	a,x
	pshs	y			; ,s is end of plucks data

_pluck_check_data:
	lda	,x
	bne	_pluck_check_data_not_empty
	leax	4,x
	cmpx	,s
	bne	_pluck_check_data

	puls	y
	lda	#1			; There are no spare pluck slots
	rts

_pluck_check_data_not_empty:
	puls	y
	clra				; Screen is not clear
	rts

************************

pluck_check_empty_lines:

	ldx	#pluck_line_counts

_pluck_check_empty_test_line:
	tst	,x+
	bne	_pluck_check_empty_line_not_empty
	cmpx	#pluck_line_counts_end
	bne	_pluck_check_empty_test_line

	lda	#1			; Lines are now clear
	rts

_pluck_check_empty_line_not_empty:
	clra				; Lines are not clear
	rts

******************
* Pluck - Continue
*
* Inputs: None
* Outputs: None
******************

pluck_continue:

	jsr	pluck_find_a_spare_slot		; Is there a spare slot?
	tsta
	beq	_pluck_do_a_frame		; No, just keep processing

	jsr	pluck_a_char			; Yes, pluck a character

_pluck_do_a_frame:

	jsr	pluck_do_frame			; Do one frame

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

	lda	simultaneous_plucks
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
	bsr	pluck_char_choose_line	; Chosen line is in A

	ldy	#pluck_line_counts

	tst	a,y		; If there are no more characters on this line
	beq	_pluck_char_get_random	; choose a different one

	dec	a,y		; There'll be one less character after this

	ldb	#COLS_PER_LINE
	mul 			; Multiply b by 32 and put the answer in D

	ldx	#TEXTBUF+COLS_PER_LINE ; Make X point to the end of the line
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
	lda	#PLUCK_PHASE_TURN_WHITE	; This is our new phase
	sta	,x+		; Store our new phase
	stb	,x+		; the character
	sty	,x		; And where it is

; Now turn it into a white box

	lda	#WHITE_BOX
	sta	,y

; Now play the pluck sound

	bsr	pluck_play_sound

	rts

*************************

_pluck_a_char_impossible:
	bra	_pluck_a_char_impossible	; Should never get here

***********************

pluck_char_choose_line:

	bsr	get_random 	; Get a random number in D
	tfr	b,a
	anda	#0b00001111	; Make the random number between 0 and 15
	cmpa	#PLUCK_LINES
	beq	pluck_char_choose_line	; But don't choose line 15

	rts

*****************

pluck_play_sound:

	lda	#1
	ldx	#pop_sound	; interrupts and everything else
	ldy	#pop_sound_end 	; pause while we're doing this
	jsr	play_sound	; Play the pluck noise
	rts

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

	cmpa	#PLUCK_PHASE_NOTHING	; tsta
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

*****************************
* Wait for a number of frames
*
* Inputs:
* A = number of frames
*****************************

wait_frames:

	pshs	a
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	puls	a
	bne	_wait_frames_skip	; User wants to skip

	deca
	bne	wait_frames

_wait_frames_skip:
	rts

**********************************************************
* Returns a random-ish number from 0...65535
*
* Output:
* D = The random number
**********************************************************

USE_DEEKS_CODE	EQU	1

	IF	(USE_DEEKS_CODE==0)

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

*********************
* Joke startup screen
*
* Inputs: None
* Outputs: None
*********************

joke_startup_screen:

	jsr	clear_screen	; Just clear the screen

	lda	#WAIT_PERIOD
	jsr	wait_frames			; Wait a certain no of frames

	ldx	#joke_startup_messages
	jsr	display_messages
	tsta
	bne	_skip_joke_startup

	lda	#WAIT_PERIOD
	jsr	wait_frames			; Wait a certain no of frames

_skip_joke_startup:
	rts

joke_startup_messages:

	FCV	"INCORPORATING CLEVER IDEAS...",0
	FCV	"%DONE",0,0
	FCV	"UTILIZING MAXIMUM PROGRAMMING",0
	FCV	"SKILL...% DONE",0,0
	FCV	"INCLUDING EVER SO MANY",0
	FCV	"AWESOME EFFECTS...% DONE",0,0
	FCV	"READYING ALL YOUR FAVORITE",0
	FCV	"DEMO CLICHES...% DONE",0,0
	FCV	"STARTING THE SHOW...%%%%%%"

	FCB	255

******************
* Display messages
*
* Inputs:
* X = Messages
******************

display_messages:

	lda	#COLS_PER_LINE
	ldy	#TEXTBUF

_display_messages_loop:
	ldb	,x+
	beq	_next_line
	cmpb	#'%' + 64
	beq	_message_pause
	cmpb	#255
	beq	_display_messages_end
	stb	,y+

	pshs	a,x,y

	cmpb	#GREEN_BOX
	beq	_display_messages_skip_sound
	bsr	display_messages_play_sound

_display_messages_skip_sound:
	lda	#2
	jsr	wait_frames
	tsta
	puls	a,x,y
	beq	_display_messages_loop	; User has not skipped

_display_messages_end:
	rts

_message_pause:
	pshs	a,x,y
	lda	#WAIT_PERIOD
	jsr	wait_frames
	tsta
	puls	a,x,y
	bne	_display_messages_end
	bra	_display_messages_loop

_next_line:
	pshs	a,x
	tfr	y,d
	addd	#COLS_PER_LINE
	andb	#0b11100000
	tfr	d,y
	lda	#5
	jsr	wait_frames
	tsta
	puls	a,x
	bne	_display_messages_end
	bra	_display_messages_loop

display_messages_play_sound:
	lda	#1
	ldx	#pluck_sound	 ; interrupts and everything else
	ldy	#pluck_sound_end   ; pause while we're doing this
	jsr	play_sound	 ; Play the pluck noise
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
*
* Outputs: None
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

_play_sound_delay_loop:
	tstb
	beq	_play_sound		; Have we completed the delay?

	decb				; If not, then wait some more

	bra	_play_sound_delay_loop

******************
* Clear the screen
*
* Inputs: None
* Outputs: None
******************

clear_screen:

	ldx	#TEXTBUF
	ldd	#(GREEN_BOX << 8 | GREEN_BOX)	; Two green boxes

_clear_screen_loop:
	std	,x++
	std	,x++
	std	,x++
	std	,x++

	cmpx	#TEXTBUFEND		; Finish in the lower-right corner
	bne	_clear_screen_loop
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
	ldb	#COLS_PER_LINE
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
        addd    #COLS_PER_LINE
        tfr     d,x
	tfr	u,d		; Get B back
	leax	b,x
	bra	_display_text_graphic_loop

_display_text_graphic_finished:
	rts

****************
* Loading screen
****************

loading_screen:

	jsr	clear_screen

	lda	#WAIT_PERIOD
	jsr	wait_frames

	lda	#1
	clrb
	ldx	#baby_elephant
	jsr	display_text_graphic

	ldx	#loading_text
	lda	#15
	ldb	#11
	jsr	display_text_graphic

	rts

loading_text:

	FCV	"LOADING...",0

* This art is by Shanaka Dias at asciiart.eu, and modified by me

baby_elephant:
	FCV	"     ..-- ,.--.",0
	FCV	"   .'   .'    /",0
	FCV	"   ! @       !'..--------..",0
	FCV	"  /      \\../              '.",0
	FCV	" /  .-.-                     \\",0
	FCV	"(  /    \\                     !",0
	FCV	" \\\\      '.                  !#",0
	FCV	"  \\\\       \\   -.           /",0
	FCV	"   \\\\       !    ).......'   \\",0
	FCV	"    \"        !   /  \\  /  \\   )",0
	FCV	"      SND   !   !./'  :.. \.-'",0
	FCV	"            '--'",0
	FCB	255
baby_elephant_end:

***********************************
* Uninstall our IRQ service routine
*
* Inputs: None
* Outputs: None
***********************************

uninstall_irq_service_routine:

	jsr	switch_off_irq

	ldy	decb_irq_service_routine
	sty	IRQ_HANDLER

	jsr	switch_on_irq

	rts

*************************************
* Here is our raw data for our sounds
*************************************

pop_sound:
	INCLUDEBIN "Sounds/Pop/Pop.raw"
pop_sound_end:

pluck_sound:
	INCLUDEBIN "Sounds/Type/Type.raw"
pluck_sound_end:
