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
* https://commons.wikimedia.org/wiki/File:Modelm.ogg
* The ASCII art of the baby elephant is by Shanaka Dias at asciiart.eu

* DEBUG_MODE means you press T to toggle frame-by-frame mode.
* In frame-by-frame mode, you press F to see the next frame.
* Also, you can optionally have the lower right corner character
* cycle when the interrupt request service routine operates.
* Press C to turn this off or on.

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
	jsr	loading_screen

	jsr	restore_basic_irq_service_routine

	clra
	clrb
	rts		; Return to Disk Extended Color BASIC

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

**********************
* Zero the DP register
*
* Inputs: None
* Outputs: None
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

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off IRQ interrupts for now

	bsr	get_irq_handler
	bsr	set_irq_handler

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

*****************
* Get IRQ handler
*
* Inputs: None
* Outputs: None
*****************

IRQ_HANDLER	EQU	$10D

get_irq_handler:

	ldx	IRQ_HANDLER		; Load the current vector into X
	stx	decb_irq_service_routine	; We will call it at the end
						; of our own handler
	rts

*****************
* Set IRQ handler
*
* Inputs: None
* Outputs: None
*****************

set_irq_handler:

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine
					; is installed

	rts

***************************************************
* Our IRQ handler
*
* Make sure decb_irq_service_routine is initialized
*
* Inputs: Not applicable
* Outputs: Not applicable
***************************************************

vblank_happened:

	RZB	1

irq_service_routine:

	lda	#1			; If waiting for VBlank,
	sta	vblank_happened		; here's the signal

	IF	DEBUG_MODE
	bsr	cycle_corner_character
	ENDIF

		; In the interests of making our IRQ handler run fast,
		; the routine assumes that decb_irq_service_routine
		; has been correctly initialized

	jmp	[decb_irq_service_routine]

decb_irq_service_routine:

	RZB	2

************************
* Cycle corner character
*
* Inputs: None
* Outputs: None
************************

cycle:

	FCB	255	; Start with it turned on

; For debugging, this provides a visual indication that
; our handler is running

cycle_corner_character:

	tst	cycle
	beq	_skip_cycle
	inc	(TEXTBUFEND-1)	; The lower-right corner character cycles

_skip_cycle:

	rts

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

	bsr	set_audio_port_on
	bsr	set_ddra

	rts

*******************
* Set audio port on
*
* Inputs: None
* Outputs: None
*******************

set_audio_port_on:

* This code was modified from code written by Trey Tomes

	lda	AUDIO_PORT_ON
	ora	#0b00001000
	sta	AUDIO_PORT_ON	; Turn on 6-bit audio

* End code modified from code written by Trey Tomes

	rts

***************
* Set DDRA
*
* Inputs: None
* Outputs: None
***************

set_ddra:

* This code was written by other people, taken from
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
* and then modified by me

	ldb	PIA2_CRA
	andb	#0b11111011
	stb	PIA2_CRA

	lda	#0b11111100
	sta	DDRA

	orb	#0b00000100
	stb	PIA2_CRA

* End of code modified by me from code written by other people

	rts

*************************
* Text buffer information
*************************

TEXTBUF		EQU	$400		; We're usually not double-buffering
TEXTBUFSIZE	EQU	$200		; so there's only one text screen
TEXTBUFEND	EQU	(TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE	EQU	32
TEXT_LINES	EQU	16

BOTTOM_LINE	EQU	(TEXT_LINES-1)

**************************************************
* Display skip message at the bottom of the screen
*
* Inputs: None
* Outputs: None
**************************************************

display_skip_message:

	lda	#BOTTOM_LINE		; Bottom line of the screen
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
* A = line to put it on (0 to 15)
* X = string containing the message (ended by a zero)
*
* Outputs: None
*****************************************************

display_message:

	tfr	x,u
	pshs	u				; U = string

	clrb
	bsr	get_screen_position		; X = Screen position

	puls	u

_display_message_loop:
	cmpx	#TEXTBUFEND
	bhs	_display_message_finished	; End of text buffer
	lda	,u+
	beq	_display_message_finished	; Terminating zero was found
	sta	,x+
	bra	_display_message_loop

_display_message_finished:
	rts

*********************
* Get screen position
*
* Inputs:
* A = Row (0-15)
* B = Column (0-31)
*
* Output:
* X = Screen position
*********************

get_screen_position:

;   X = TEXTBUF + A * COLS_PER_LINE + B

	pshs	b

	ldb	#COLS_PER_LINE
	mul
	ldx	#TEXTBUF
	leax	d,x

	puls	b
	abx

	rts

***************
* Pluck routine
*
* Inputs: None
* Outputs: None
***************

PLUCK_LINES	EQU	(TEXT_LINES-1)	; The bottom line of
					; the screen is for
					; our skip message

GREEN_BOX	EQU	$60	; These are MC6847 codes
WHITE_BOX	EQU	$CF

simultaneous_plucks:

	RZB	1

pluck_line_counts:

	RZB PLUCK_LINES			; 15 zeroes

pluck_line_counts_end:

plucks_data:

	RZB	MAX_SIMULTANEOUS_PLUCKS * 4	; Reserve 4 bytes per pluck

plucks_data_end:

; The structure of an entry in plucks_data is:
; phase     (1 byte),
; character (1 byte),
; position  (2 bytes)

MAX_SIMULTANEOUS_PLUCKS	EQU	10

PLUCK_PHASE_NOTHING	EQU	0
PLUCK_PHASE_TURN_WHITE	EQU	1
PLUCK_PHASE_PLAIN	EQU	2
PLUCK_PHASE_PULLING	EQU	3

pluck_the_screen:

; First, start with just one pluck at a time

	lda	#1
	sta	simultaneous_plucks

; Second, count the number of characters on each line of the screen

	jsr	pluck_count_chars_per_line

; Now do it

	bsr	pluck_loop
	rts

***********************************
* Pluck - Count characters per line
*
* Inputs: None
* Outputs: None
***********************************

pluck_count_chars_per_line:

	ldx	#TEXTBUF
	ldu	#pluck_line_counts

_pluck_count_loop:
	bsr	count_char
	bsr	increment_u

	cmpu	#pluck_line_counts_end
	blo	_pluck_count_loop

	rts

*************************************
* Count char
*
* Inputs:
* X = Current text buffer position
* U = Current line count
*
* Outputs:
* X = Updated text buffer position
* U = (Unmodified) Current line count
*************************************

count_char:

	lda	#GREEN_BOX
	cmpa	,x+
	beq	_skip_count

	inc	,u		; Count non-spaces only

_skip_count:
	rts

***********************************************
* Increment U
*
* Inputs:
*
* X = Current text buffer position
* U = Current line count
*
* Outputs:
* X = (Unmodified) Current text buffer position
* U = Current line count
***********************************************

increment_u:

	pshs	x,u
	tfr	x,d
	bsr	is_d_divisible_by_32
	tsta
	puls	x,u
	bne	_increment

	rts

_increment:
	leau	1,u

	rts

************************************
* Is D divisible by 32
*
* Inputs:
* D = any unsigned number or pointer
*
* Output:
* A = 0           No it isn't
* A = (Non-zero)  Yes it is
************************************

is_d_divisible_by_32:

	andb	#0b00011111
	beq	_divisible

	clra
	rts

_divisible:
	lda	#1
	rts

***************
* Pluck loop
*
* Inputs: None
* Outputs: None
***************

pluck_loop:

; If the user wants to skip, we finish

	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	_pluck_finished

; If the screen is empty, we finish

	jsr	pluck_is_screen_empty
	tsta
	bne	_pluck_finished

; Otherwise, keep going

	jsr	process_pluck

	bra	pluck_loop

_pluck_finished:
	clra
	rts

******************************************
* Wait for VBlank and check for skip
*
* Inputs: None
*
* Output:
* A = 0          -> A VBlank happened
* A = (Non-zero) -> User is trying to skip
******************************************

wait_for_vblank_and_check_for_skip:

	clr	vblank_happened

_wait_for_vblank_and_check_for_skip_loop:
	bsr	poll_keyboard
	cmpa	#1
	beq	_skip
	cmpa	#2
	beq	_wait_for_vblank_and_check_for_skip_loop

	tst	vblank_happened
	beq	_wait_for_vblank_and_check_for_skip_loop

	clra		; A VBlank happened
	rts

_skip:
	lda	#1	; User skipped
	rts

*****************************
* Define POLCAT and BREAK_KEY
*****************************

; POLCAT is a pointer to a pointer

POLCAT		EQU	$A000

BREAK_KEY	EQU	3

*******************************
* Poll keyboard
*
* Inputs:
* A = Keypress
*
* Output:
* A = 0 No input
* A = 1 User wants to skip
* A = 2 Require an F to proceed
*******************************

poll_keyboard:

	jsr	[POLCAT]		; POLCAT is a pointer to a pointer
	cmpa	#' '			; Space bar
	beq	_wait_for_vblank_skip
	cmpa	#BREAK_KEY		; Break key
	beq	_wait_for_vblank_skip

	ldb	#DEBUG_MODE
	bne	debugging_mode_is_on

	clra		; Debug mode is off, so exit normally
	rts

_wait_for_vblank_skip:
	lda	#1	; User wants to skip
	rts

*******************************
* Debugging mode on
*
* Inputs: None
* Outputs:
* A = 0 All normal
* A = 2 Require F to go forward
*******************************

debugging_mode_is_on:

	cmpa	#'T'
	beq	invert_frame_by_frame_toggle
	cmpa	#'C'
	beq	toggle_cycle

_key_processed:
	ldb	frame_by_frame_mode_toggle
	bne	require_f

	clra
	rts

toggle_cycle:

	com	cycle
	bra	_key_processed

**********************************
* Invert frame-by-frame toggle
*
* Input:
* A = Keypress
*
* Output:
* A = (Unchanged) Keypress
**********************************

frame_by_frame_mode_toggle:

	RZB	1

invert_frame_by_frame_toggle:

	com	frame_by_frame_mode_toggle
	bra	_key_processed

*******************************
* Require F
*
* Input:
* A = Keypress
*
* Output:
* A = 0 All is well
* A = 2 Require an F to proceed
*******************************

require_f:

	cmpa	#'F'		; If toggle is on, require an F
	beq	_forward		; to go forward 1 frame

	lda	#2		; If no F, go back to polling the keyboard
	rts

_forward:
	clra
	rts

*************************************************
* Pluck - check to see if the screen is empty yet
*
* Inputs: None
*
* Outputs:
* A = (Non-zero) Screen is empty
* A = 0          Screen is not empty
*************************************************

pluck_is_screen_empty:

	bsr	pluck_check_empty_slots
	tsta
	beq	_pluck_screen_not_empty

	bsr	pluck_are_lines_empty
	rts

_pluck_screen_not_empty:
	clra				; Screen is not clear
	rts

**********************************************************
* Pluck check empty slots
*
* Inputs: None
*
* Output:
* A = 0 At least 1 slot is being used, screen is not clear
* A = (Non-zero) All slots are empty
**********************************************************

pluck_check_empty_slots:

	bsr	get_pluck_data_end
	pshs	x			; ,s is end of plucks data
	ldx	#plucks_data

_pluck_check_data:
	lda	,x
	bne	_pluck_check_data_not_empty
	leax	4,x
	cmpx	,s
	blo	_pluck_check_data

	puls	x
	lda	#1			; There are no spare pluck slots
	rts

_pluck_check_data_not_empty:
	puls	x
	clra				; Screen is not clear
	rts

********************
* Get pluck data end
*
* Inputs: None
*
* Outputs:
* X = Address
********************

get_pluck_data_end:

; X = #plucks_data + 4 * simultaneous_plucks

	ldx	#plucks_data
	lda	simultaneous_plucks	; Multiply this by 4
	lsla
	lsla
	leax	a,x
	rts

************************************
* Pluck - Are lines empty
*
* Inputs: None
*
* Output:
* A = 0 Lines are not clear
* A = (Non-zero) All lines are clear
************************************

pluck_are_lines_empty:

	ldx	#pluck_line_counts

_pluck_are_lines_empty_test_line:
	tst	,x+
	bne	_pluck_are_lines_empty_line_not_empty
	cmpx	#pluck_line_counts_end
	blo	_pluck_are_lines_empty_test_line

	lda	#1			; Lines are now clear
	rts

_pluck_are_lines_empty_line_not_empty:
	clra				; Lines are not clear
	rts

***************
* Process pluck
*
* Inputs: None
* Outputs: None
***************

process_pluck:

	jsr	pluck_count_frames
	jsr	pluck_continue

	rts

***********************************
* Pluck - Count frames
*
* Inputs: None
* Outputs: None
***********************************

pluck_frames:

	RZB	1

pluck_count_frames:

	lda	pluck_frames
	inca
	sta	pluck_frames			; Keep count of the frames

	cmpa	#50				; Every 50 frames,
	bne	_skip_increase

	clr	pluck_frames			; reset the counter, and

	lda	simultaneous_plucks		; increase the number of plucks
	cmpa	#MAX_SIMULTANEOUS_PLUCKS	; happening at the same time
	bhs	_skip_increase

	inc	simultaneous_plucks		; fallthrough to rts

_skip_increase:
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
	beq	_pluck_continue_do_a_frame	; No, just keep processing

	jsr	pluck_a_char			; Yes, pluck a character

_pluck_continue_do_a_frame:

	jsr	pluck_do_frame			; Do one frame

	rts

*****************************************
* Pluck - Find a spare slot
*
* Inputs: None
*
* Outputs:
* A = (Non-zero) There is a spare slot
* A = 0		 There isn't a spare slot
* X = (If A is non-zero) The slot address
*****************************************

pluck_find_a_spare_slot:

	bsr	get_pluck_data_end
	pshs	x			; ,S = End of pluck lines
	ldx	#plucks_data		;  X = Our pointer to pluck data

	bsr	pluck_find_loop
	leas	2,s
	rts

*****************************************
* Pluck find loop
*
* Inputs:
*   X = Pointer to pluck data
* 2,S = Pointer to end of pluck data
*
* Outputs:
* A = (Non-zero) There is a spare slot
* A = 0		 There isn't a spare slot
* X = (If A is non-zero) The slot address
*****************************************

pluck_find_loop:

	cmpx	2,s
	bhs	_pluck_find_no_empty_slot
	tst	,x			; compare to #PLUCK_PHASE_NOTHING
	beq	_pluck_find_found_empty
	leax	4,x
	bra	pluck_find_loop

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

	bsr	pluck_are_lines_empty
	tsta
	bne	_no_chars_left
	bsr	pluck_char_choose_line
	bsr	pluck_get_char
	bsr	pluck_char

_no_chars_left:
	rts			; No more unplucked characters left

*********************************
* Pluck a character - Choose line
*
* Inputs: None
*
* Output:
* A = Line number
*********************************

pluck_char_choose_line:

	bsr	pluck_char_choose_random_line	; Chosen line is in A

	ldx	#pluck_line_counts

	tst	a,x	; If there are no more characters on this line
	beq	pluck_char_choose_line		; choose a different one

	dec	a,x		; There'll be one less character after this

	rts

*********************************
* Pluck char - Choose random line
*
* Inputs: None
*
* Output:
* A = Chosen line
*********************************

pluck_char_choose_random_line:

	jsr	get_random 	; Get a random number in D
	tfr	b,a
	anda	#0b00001111	; Make the random number between 0 and 15
	cmpa	#BOTTOM_LINE
	beq	pluck_char_choose_random_line	; But don't choose line 15

	rts

*******************************************************
* Pluck - Get char
*
* Inputs:
* A = Line number
*
* Outputs:
* X = Pointer to screen position of pluckable character
*******************************************************

pluck_get_char:
	jsr	get_end_of_line

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

	rts

********************************************
* Get end of line
*
* Input:
* A = Line to pluck from
*
* Output:
* X = Screen position of the end of the line
********************************************

get_end_of_line:

	clrb
	jsr	get_screen_position

	; Make X point to the right end of the line

	leax	COLS_PER_LINE,x

	rts

************************************************
* Pluck - Pluck character
*
* Input:
* X = Screen position of character to be plucked
*
* Outputs:None
************************************************

pluck_char:

	bsr	pluck_register
	bsr	place_white_box
	bsr	pluck_play_sound

	rts

************************************************
* Pluck - Register
*
* Input:
* X = Screen position of character being plucked
*
* Outputs:
* X = Screen position of character being plucked
************************************************

pluck_register:

	tfr	x,u
	pshs	u
	jsr	pluck_find_a_spare_slot	; This call shouldn't fail
	tsta
	beq	impossible
	puls	u
	ldb	,u		; B = the character being plucked
				; X is the slot
				; U is the screen position
	lda	#PLUCK_PHASE_TURN_WHITE	; This is our new phase
	sta	,x+		; Store our new phase
	stb	,x+		; the character
	stu	,x		; And where it is

	tfr	u,x		; Return X

	rts

***************
* Impossible
*
* Inputs: None
* Outputs: None
***************

impossible:

	lda	#'?' +  64
	sta	$400

	bra	_impossible	; Should never get here


*********************
* Place white box
* Input:
* X = Screen position
*
* Outputs: None
*********************

place_white_box:

	lda	#WHITE_BOX
	sta	,x
	rts

********************
* Pluck - Play sound
*
* Inputs: None
* Outputs: None
********************

pluck_play_sound:

	lda	#1
	ldx	#pop_sound	; Interrupts and everything else
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

	pshs	b
	tfr	x,d
	andb	#0b00011111	; Is X divisible by 32?
	puls	b		; Does not affect condition codes
	beq	_pluck_phase_3_ended

	stb	,x		; Draw it in the next column
	stx	2,y		; Update position in plucks_data

	rts

_pluck_phase_3_ended:		; Character has gone off the right side
	lda	#PLUCK_PHASE_NOTHING	; clra
	sta	,y		; Store it

	rts

***********************************
* Wait for a number of frames
*
* Input:
* A = Number of frames
*
* Output:
* A = 0 Success
* A = (Non-zero) User wants to skip
***********************************

wait_frames:
	tsta				; If A = 0, immediately exit
	beq	_wait_frames_success

	pshs	a
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	puls	a
	bne	_wait_frames_skip	; User wants to skip

	deca
	bne	wait_frames

_wait_frames_success:
	clra				; Normal termination
	rts

_wait_frames_skip:
	lda	#1			; User wants to skip
	rts

********************************************
* Returns a random-ish number from 0...65535
*
* Inputs: None
*
* Output:
* D = The random number
********************************************

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

	FCB	0xBE
	FCB	0xEF

get_random:

	ldd	SEED
	lsra
	rorb
	bcc	get_random_no_feedback
	eora	#$B4

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

***********************
* Joke startup messages
***********************

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

*********************************
* Display messages
*
* Inputs:
* X = Messages
*
* Outputs:
* A = 0 Success
* A = (Non-zero) User has skipped
*********************************

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
	beq	_display_messages_space

	bsr	display_messages_play_sound

	lda	#2
	jsr	wait_frames
	tsta

_display_messages_continue:
	puls	a,x,y
	beq	_display_messages_loop	; If branch is taken,
					; user has not skipped

_display_messages_skip:
	lda	#1		; User wants to skip
	rts

_display_messages_end:
	clra
	rts

_display_messages_space:
	lda	#15		; silence for 15 frames
	jsr	wait_frames
	tsta
	bra	_display_messages_continue

_message_pause:
	pshs	a,x,y
	lda	#WAIT_PERIOD
	jsr	wait_frames
	tsta
	puls	a,x,y
	beq	_display_messages_loop

	lda	#1		; User wants to skip
	rts

_next_line:
	pshs	a,x
	tfr	y,d
	addd	#COLS_PER_LINE
	andb	#0b11100000
	tfr	d,y
	pshs	y
	lda	#5
	jsr	wait_frames
	tsta
	puls	y
	puls	a,x
	bne	_display_messages_skip
	bra	_display_messages_loop

display_messages_play_sound:
	lda	#1
	ldx	#pluck_sound		; Interrupts and everything else
	ldy	#pluck_sound_end	; pause while we're doing this
	jsr	play_sound		; Play the pluck noise
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
	blo	_clear_screen_loop
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
*
* Inputs: None
* Outputs: None
****************

loading_screen:

	jsr	clear_screen

	lda	#WAIT_PERIOD
	jsr	wait_frames

	lda	#1
	clrb
	ldx	#baby_elephant
	jsr	display_text_graphic

	lda	#15
	ldx	#loading_text
	jsr	display_message

	rts

loading_text:

	FCV	"           LOADING...",0

***************************
* ASCII art - Baby elephant
***************************

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
	FCV	"   :\\       !    ).......'   \\",0
	FCV	"    \"       !   /  \\   !  \\   )",0
	FCV	"      SND   !   !./'   :.. \.-'",0
	FCV	"            '--'",0
	FCB	255

baby_elephant_end:

*************************************
* Restore BASIC's IRQ service routine
*
* Inputs: None
* Outputs: None
*************************************

restore_basic_irq_service_routine:

	jsr	switch_off_irq
	bsr	restore_irq_handler
	jsr	switch_on_irq

	rts

restore_irq_handler:

	ldx	decb_irq_service_routine
	stx	IRQ_HANDLER

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
