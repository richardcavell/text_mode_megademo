* This is Part 1 of Text Mode Demo
* by Richard Cavell
* June - August 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This demo part is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* Part of this code was written by Simon Jonassen (The Invisible Man)
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by a number of other authors
* You can see here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
* Part of this code was written by Sean Conner (Deek)
*
* The sound Pop.raw is from Mouth_pop.ogg by Cori from Wikimedia Commons
* https://commons.wikimedia.org/wiki/File:Mouth_pop.ogg
* The sound Type.raw is from Modelm.ogg by Cpuwhiz13 from Wikimedia Commons
* https://commons.wikimedia.org/wiki/File:Modelm.ogg
*
* The ASCII art of the baby elephant is by Shanaka Dias at asciiart.eu
*
* If DEBUG_MODE is non-zero, then Debug Mode is "on".
* If Debug Mode is on:
*   1) You can press T to toggle frame-by-frame mode
*        In frame-by-frame mode, you press F to see the next frame.
*   2) You can have the lower right corner character cycle when the
*      interrupt request routine is called
*        Press C to turn the cycling of the lower-right character off or on
*   3) You can see if there are dropped frames
*      The lower left corner will display how many frames have been skipped
*        (0 to 9 and up arrow meaning 10 or more)
*        Press D to turn the dropped frames counter off or on
*   4) You can see the number of simultaneous plucks
*      In the lower left corner, to the right of the dropped frame counter
*      From 0 to 9, plus up arrow meaning 10 or more

DEBUG_MODE	EQU	0

* Between each section, wait this number of frames

WAIT_PERIOD	EQU	25

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

*****************
* Part 1 Sequence
*
* Inputs: None
*
* Output:
* D = 0 Success
*****************

	jsr	set_dp_register_for_hsync	; For sound playback
	jsr	turn_on_debug_features		; Turn on debugging features
	jsr	install_irq_service_routine	; Install our IRQ handler
	jsr	turn_off_disk_motor		; Silence the disk drive
	jsr	turn_6bit_audio_on		; Turn on the 6-bit DAC
	jsr	turn_on_interrupts		; Turn on interrupts

	jsr	display_skip_message
	jsr	pluck_the_screen		; First section
	jsr	joke_startup_screen		; Second section
	jsr	turn_off_interrupts		; Go back to what BASIC uses
	jsr	loading_screen
	jsr	print_loading_text

	jsr	restore_basic_irq_service_routine
	jsr	zero_dp_register		; Zero the DP register

	ldd	#0
	rts		; Return to Disk Extended Color BASIC

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

***************************
* Set DP register for HSYNC
*
* Inputs: None
* Outputs: None
***************************

* This code was written by Simon Jonassen and modified by me

set_dp_register_for_hsync:

	jsr	switch_off_irq_and_firq
	lda	#irq_service_routine/256
	tfr	a,dp
	SETDP	irq_service_routine/256
	jsr	switch_on_irq_and_firq
	rts

* End of code written by Simon Jonassen and modified by me

************************
* Turn on debug features
*
* Inputs: None
* Outputs: None
************************

turn_on_debug_features:

	lda	#DEBUG_MODE		; If we are in DEBUG mode,
	beq	_not_in_debug_mode

	lda	#255			; load #255 into these variables
	sta	cycle_lower_right
	sta	dropped_frame_counter_toggle

_not_in_debug_mode:
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

IRQ_INSTRUCTION	EQU	$10C
IRQ_HANDLER	EQU	$10D

get_irq_handler:

	lda	IRQ_INSTRUCTION		; Should be JMP (extended)
	sta	decb_irq_service_instruction

	ldx	IRQ_HANDLER			; Load the current vector into X
	stx	decb_irq_service_routine	; We could call it at the end
						; of our own handler
	rts

*****************
* Set IRQ handler
*
* Inputs: None
* Outputs: None
*****************

set_irq_handler:

	lda	#$0e			; DP JMP
	sta	IRQ_INSTRUCTION		; Shaves off 1 byte

	lda	#irq_service_routine&255
	sta	IRQ_HANDLER

; The last byte stays the same

	rts

*************************
* Text buffer information
*************************

TEXTBUF		EQU	$400	; We're not double-buffering in this part
TEXTBUFSIZE	EQU	$200	; so there's only one text screen
TEXTBUFEND	EQU	(TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE	EQU	32
TEXT_LINES	EQU	16

LOWER_LEFT_CORNER	EQU	$5E0
LOWER_RIGHT_CORNER	EQU	$5FF

BOTTOM_LINE	EQU	(TEXT_LINES-1)

******************************************************
* Variables that are relevant to vertical blank timing
******************************************************

waiting_for_vblank:

	RZB	1		; The interrupt handler reads this

vblank_happened:

	RZB	1		; and sets this

dropped_frames:

	RZB	1		; From 0 to 10 (don't count more than 10)

waiting_for_f:

	RZB	1		; You have to press F to go forward

**********************************************
* Variables relating to DECB's own IRQ handler
**********************************************

decb_irq_service_instruction:

	RZB	1		; Should be JMP (extended)

decb_irq_service_routine:

	RZB	2

call_decb_irq_handler:		; We get significantly better performance
				; by ignoring DECB's IRQ handler
	RZB	1

*****************************
* PIA memory-mapped registers
*****************************

PIA0AD	EQU	$FF00
PIA0AC	EQU	$FF01
PIA0BD	EQU	$FF02
PIA0BC	EQU	$FF03

*************************
* Our IRQ handler
*
* Inputs: Not applicable
* Outputs: Not applicable
*************************

irq_service_routine:

	lda	PIA0BC		; Was it a VBlank or HSync?
	bmi	service_vblank	; VBlank - go there

* If HSYNC, fallthrough to HSYNC handler

*************************
* Service HSYNC
*
* Inputs: Not applicable
* Outputs: Not applicable
*************************

* This code was written by Simon Jonassen and modified by me

	clra

smp_1:	ldx	#0		; pointer to sample
end_1:	cmpx	#0		; done ?
	beq	_silent_1

	adda	,x+		; Get the next byte of data
	stx	smp_1+1		; Self-modifying code here

_silent_1:

smp_2:	ldx	#0
end_2:	cmpx	#0
	beq	_silent_2

	adda	,x+
	stx	smp_2+1

_silent_2:

smp_3:	ldx	#0
end_3:	cmpx	#0
	beq	_silent_3

	adda	,x+
	stx	smp_3+1

_silent_3:

smp_4:	ldx	#0
end_4:	cmpx	#0
	beq	_silent_4

	adda	,x+
	stx	smp_4+1

_silent_4:
	sta	AUDIO_PORT	; and shove it into the audio port

	lda	PIA0AD		; Acknowledge HSYNC interrupt
	rti

* End of code that was written by Simon Jonassen and modified by me

	IF	DEBUG_MODE

********************************
* Service VBlank (DEBUG version)
*
* Inputs: Not applicable
* Outputs: Not applicable
********************************

service_vblank:

	lda	waiting_for_vblank	; The demo is waiting for the signal
	bne	_no_dropped_frames	; so let's give it to them

	bsr	count_dropped_frame	; If the demo is not ready for a
	bra	_dropped_frame		; vblank, then we drop a frame

_no_dropped_frames:
	bsr	signal_demo		; VBlank has happened

_dropped_frame:
	bsr	print_dropped_frames
	bsr	print_simultaneous_plucks
	bsr	cycle_corner_character
	bra	exit_irq_handler

	ENDIF

	IF	(DEBUG_MODE==0)

************************************
* Service VBlank (non-DEBUG version)
*
* Inputs: Not applicable
* Outputs: Not applicable
************************************

service_vblank:

	lda	waiting_for_vblank	; The demo is waiting for the signal
	beq	_dropped_frame
	clr	waiting_for_vblank	; No longer waiting
	lda	#1			; If waiting for VBlank,
	sta	vblank_happened		; here's the signal

_dropped_frame:
	lda	PIA0BD			; Acknowledge interrupt
	rti

	ENDIF

*********************
* Count dropped frame
*
* Inputs: None
* Outputs: None
*********************

count_dropped_frame:

	lda	waiting_for_f
	bne	_skip_increment

	lda	dropped_frames
	cmpa	#10
	beq	_skip_increment		; Stop counting dropped frames at 10

	inca
	sta	dropped_frames

_skip_increment:
	rts

***************
* Signal demo
*
* Inputs: None
* Outputs: None
***************

signal_demo:

	clr	waiting_for_vblank	; No longer waiting
	lda	#1			; If waiting for VBlank,
	sta	vblank_happened		; here's the signal

	clr	dropped_frames

	rts

**********************
* Print dropped frames
*
* Inputs: None
* Outputs: None
**********************

print_dropped_frames:

	lda	dropped_frame_counter_toggle
	beq	_do_not_print_frame_counter

	lda	dropped_frames
	cmpa	#10
	blo	_adjust_a

	lda	#94			; This is the up arrow
	bra	_store_a

_adjust_a:
	adda	#'0'+64

_store_a:
	sta	LOWER_LEFT_CORNER	; Put it in the lower-left corner

_do_not_print_frame_counter:
	rts

***************************
* Print simultaneous plucks
*
* Inputs: None
* Outputs: None
***************************

print_simultaneous_plucks:

	clra
	ldx	#plucks_data

_simul_loop:
	tst	,x
	beq	_skip_count_simul

	inca

_skip_count_simul:
	leax	4,x
	cmpx	#plucks_data_end
	blo	_simul_loop

        cmpa    #10
        blo     _adjust_sp_counter

        lda     #94                     ; This is the up arrow
        bra     _store_sp_counter

_adjust_sp_counter:
        adda    #'0'+64

_store_sp_counter:
        sta     LOWER_LEFT_CORNER+1       ; Put it in the lower-left corner + 1

        rts

************************
* Cycle corner character
*
* Inputs: None
* Outputs: None
************************

cycle_lower_right:

	FCB	0	; If DEBUG_MODE is on, this will start with 255

; For debugging, this provides a visual indication that
; our IRQ handler is running

cycle_corner_character:

	lda	cycle_lower_right
	beq	_skip_cycle

	lda	waiting_for_f
	bne	_skip_cycle

	inc	LOWER_RIGHT_CORNER ; The lower-right corner character cycles

_skip_cycle:

	rts

******************
* Exit IRQ handler
******************

exit_irq_handler:

	lda	call_decb_irq_handler
	beq	_rti_from_here
	ldx	decb_irq_service_routine
	beq	_rti_from_here
	jmp	,x

_rti_from_here:
	lda	PIA0BD			; Acknowledge interrupt
	rti

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
	bsr	set_ddra_bits_to_input

	rts

*******************
* Set audio port on
*
* Inputs: None
* Outputs: None
*******************

set_audio_port_on:

* This is modified by me from code written by Simon Jonassen

	lda	PIA0BC
	anda	#0b11110111
	sta	PIA0BC

	lda	PIA0AC
	anda	#0b11110111
	sta	PIA0AC

* End code modified from code written by Simon Jonassen

* This code was modified from code written by Trey Tomes

	lda	AUDIO_PORT_ON
	ora	#0b00001000
	sta	AUDIO_PORT_ON	; Turn on 6-bit audio

* End code modified from code written by Trey Tomes

	rts

************************
* Set DDRA bits to input
*
* Inputs: None
* Outputs: None
************************

set_ddra_bits_to_input:

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

********************
* Turn on interrupts
********************

turn_on_interrupts:

	jsr	switch_off_irq_and_firq

* This code was originally written by Simon Jonassen (The Invisible Man)
* and then modified by me

	lda	PIA0BC		; Enable VSync interrupt
	ora	#3
	sta	PIA0BC
	lda	PIA0BD		; Acknowledge any outstanding VSync interrupt

	lda	PIA0AC		; Enable HSync interrupt
	ora	#3
	sta	PIA0AC
	lda	PIA0AD		; Acknowledge any outstanding HSync interrupt

* End code modified by me from code written by Simon Jonassen

	jsr	switch_on_irq_and_firq

	rts

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

	FCV	"  PRESS SPACE TO SKIP ANY PART  "
	FCB	0

*****************************************************
* Display a message on the screen
*
* Inputs:
* A = Line to put it on (0 to 15)
* X = String containing the message (ended by a zero)
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

	tfr	d,u

	ldx	#TEXTBUF
	ldb	#COLS_PER_LINE
	mul
	leax	d,x

	tfr	u,d
	abx

	rts

*****************
* Pluck variables
*****************

PLUCK_LINES	EQU	(TEXT_LINES-1)	; The bottom line of
					; the screen is for
					; our skip message

GREEN_BOX	EQU	$60		; These are MC6847 codes
WHITE_BOX	EQU	$CF

simultaneous_plucks:

	RZB	1

pluck_line_counts:

	RZB PLUCK_LINES			; 15 zeroes

pluck_line_counts_end:

*************
* Plucks data
*************

MAX_SIMULTANEOUS_PLUCKS	EQU	10

plucks_data:

	RZB	MAX_SIMULTANEOUS_PLUCKS * 4	; Reserve 4 bytes per pluck

plucks_data_end:

; The structure of an entry in plucks_data is:
; phase     (1 byte),
; character (1 byte),
; position  (2 bytes)

PLUCK_PHASE_NOTHING	EQU	0
PLUCK_PHASE_TURN_WHITE	EQU	1
PLUCK_PHASE_PLAIN	EQU	2
PLUCK_PHASE_PULLING	EQU	3

******************
* Pluck the screen
*
* Inputs: None
* Outputs: None
******************

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

************************************************
* Count char
*
* Inputs:
* X = Current text buffer position
* U = Pointer to current line count
*
* Outputs:
* X = (Updated) Text buffer position
* U = (Unmodified) Pointer to current line count
************************************************

count_char:

	lda	#GREEN_BOX
	cmpa	,x+
	beq	_skip_count

	inc	,u		; Count non-spaces only

_skip_count:
	rts

*******************************************************
* Increment U
*
* Inputs:
*
* X = Current text buffer position
* U = Pointer to current line count
*
* Outputs:
* X = (Unmodified) Current text buffer position
* U = (Possibly modified) Pointer to current line count
*******************************************************

increment_u:

	pshs	x,u
	tfr	x,d
	bsr	is_d_divisible_by_32
	tsta
	puls	x,u		; Does not affect Condition Codes
	bne	_increment

	rts

_increment:
	leau	1,u

	rts

************************************
* Is D divisible by 32
*
* Input:
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

	jsr	process_pluck_1

	jsr	wait_for_vblank_and_check_for_skip
	tsta				; If the user wants to skip, we finish
	bne	_pluck_finished

	jsr	pluck_is_screen_empty
	tsta				; If the screen is empty, we finish
	beq	pluck_loop

_pluck_finished:
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

	clr	vblank_happened		; See "Variables that are relevant to
	lda	#1			; vertical blank timing" above
	sta	waiting_for_vblank
	clr	waiting_for_f

_wait_for_vblank_and_check_for_skip_loop:
	bsr	poll_keyboard
	cmpa	#1
	beq	_skip
	cmpa	#2
	beq	wait_for_f

	lda	vblank_happened
	beq	_wait_for_vblank_and_check_for_skip_loop

	clra		; A VBlank happened
	rts

_skip:
	lda	#1	; User skipped
	rts

***************
* Waiting for F
*
* Inputs: None
* Outputs: None
***************

wait_for_f:

	lda	#1
	sta	waiting_for_f
	bra	_wait_for_vblank_and_check_for_skip_loop

*****************************
* Define POLCAT and BREAK_KEY
*****************************

; POLCAT is a pointer to a pointer

POLCAT		EQU	$A000

BREAK_KEY	EQU	3

*******************************
* Poll keyboard
*
* Inputs: None
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
* Debugging mode is on
*
* Input:
* A = Keypress
*
* Output:
* A = 0 All normal
* A = 2 Require F to go forward
*******************************

debugging_mode_is_on:

	cmpa	#'T'
	beq	toggle_frame_by_frame
	cmpa	#'C'
	beq	toggle_cycle
	cmpa	#'D'
	beq	toggle_dropped_frame_counter

_key_processed:
	ldb	frame_by_frame_mode_toggle
	bne	require_f

	clra
	rts

**********************************
* Invert frame-by-frame toggle
*
* Input:
* A = Keypress
*
* Outputs: None
**********************************

frame_by_frame_mode_toggle:

	RZB	1

toggle_frame_by_frame:

	com	frame_by_frame_mode_toggle
	bra	_key_processed

***************
* Toggle cycle
*
* Inputs: None
* Outputs: None
***************

toggle_cycle:

	com	cycle_lower_right
	bne	_skip_redraw_cycle

					; If it's being turned off
	lda	#GREEN_BOX		; then draw over the lower-right
	sta	LOWER_RIGHT_CORNER	; corner

_skip_redraw_cycle:
	bra	_key_processed

******************************
* Toggle dropped frame counter
*
* Inputs: None
* Outputs: None
******************************

dropped_frame_counter_toggle:

	FCB	0	; If DEBUG_MODE is on, then this starts with 255

toggle_dropped_frame_counter:

	com	dropped_frame_counter_toggle
	bne	_skip_redraw_dropped_frame_counter

					; If it's being turned off
	lda	#GREEN_BOX		; then draw over the lower-left
	sta	LOWER_LEFT_CORNER	; corner

_skip_redraw_dropped_frame_counter:
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
* Pluck - Check to see if the screen is empty yet
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

	bsr	pluck_are_lines_empty	; Return whatever this returns
	rts

_pluck_screen_not_empty:
	clra				; Screen is not clear
	rts

**********************************************************
* Pluck - Check empty slots
*
* Inputs: None
*
* Output:
* A = 0 At least 1 slot is being used, screen is not clear
* A = (Non-zero) All slots are empty
**********************************************************

cache_slots_being_used:

	RZB	1		; Non-zero means at least 1 is being used
				; Zero means we must check

pluck_check_empty_slots:

	lda	cache_slots_being_used
	bne	_slots_used
	bsr	pluck_check_empty_slots_2	; Return what this returns
	sta	cache_slots_being_used
	rts

_slots_used:
	clra
	rts

**********************************************************
* Pluck - Check empty slots 2
*
* Inputs: None
*
* Output:
* A = 0 At least 1 slot is being used, screen is not clear
* A = (Non-zero) All slots are empty
**********************************************************

pluck_check_empty_slots_2:

	bsr	get_pluck_data_end
	pshs	x			; ,S is end of plucks data
	ldx	#plucks_data

_pluck_check_data:
	lda	,x
	bne	_pluck_check_data_not_empty
	leax	4,x
	cmpx	,s
	blo	_pluck_check_data

	puls	x
	lda	#1			; There are no plucks happening
	rts

_pluck_check_data_not_empty:
	puls	x
	clra				; There are plucks happening
	rts

********************
* Get pluck data end
*
* Inputs: None
*
* Outputs:
* X = Address
********************

cached_pluck_data_end:

	RZB	2

cached_pluck_data_end_is_good:

	RZB	1

get_pluck_data_end:

	lda	cached_pluck_data_end_is_good
	beq	calculate_pluck_data_end

	ldx	cached_pluck_data_end
	rts

**************************
* Calculate pluck data end
*
* Inputs: None
*
* Outputs:
* X = Address
**************************

calculate_pluck_data_end:

; X = #plucks_data + 4 * simultaneous_plucks

	ldx	#plucks_data
	lda	simultaneous_plucks	; Multiply this by 4
	lsla
	lsla
	leax	a,x

	stx	cached_pluck_data_end	; Cache the result
	lda	#1
	sta	cached_pluck_data_end_is_good

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

cached_pluck_lines_empty_is_good:

	RZB	1

cached_pluck_lines_empty:

	RZB	1

pluck_are_lines_empty:

	lda	cached_pluck_lines_empty_is_good
	bne	_return_cache

	bsr	pluck_are_lines_empty_2
	ldb	#1
	stb	cached_pluck_lines_empty_is_good
	sta	cached_pluck_lines_empty
	rts

_return_cache:
	lda	cached_pluck_lines_empty
	rts

************************************
* Pluck - Are lines empty 2
*
* Inputs: None
*
* Output:
* A = 0 Lines are not clear
* A = (Non-zero) All lines are clear
************************************

pluck_are_lines_empty_2:

	ldx	#pluck_line_counts

_test_line:
	lda	,x+
	bne	_line_not_empty
	cmpx	#pluck_line_counts_end
	blo	_test_line

_lines_are_clear:
	lda	#1			; Lines are now clear
	rts

_line_not_empty:
	clra				; Lines are not clear
	rts

*****************
* Process pluck 1
*
* Inputs: None
* Outputs: None
*****************

spare_slot:

	RZB	2

process_pluck_1:

	jsr	is_there_a_spare_sound_slot	; Is there a spare sound slot?
	tsta
	beq	_process_pluck_2		; No, just keep processing

	jsr	pluck_find_a_spare_slot		; Is there a spare data slot?
	tsta
	beq	_process_pluck_2		; No, just keep processing

	stx	spare_slot			; Save for later use

	jsr	pluck_a_char			; Yes, pluck a character

_process_pluck_2:

	jsr	process_pluck_2			; Do one frame

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
* Pluck - Find loop
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
	lda	,x			; compare to #PLUCK_PHASE_NOTHING
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
	jsr	pluck_char

_no_chars_left:
	rts		; No more unplucked characters left on the screen

*********************************
* Pluck a character - Choose line
*
* Inputs: None
*
* Output:
* A = Line number
*********************************

pluck_char_choose_line:

	bsr	pluck_collate_non_zero_lines
	bsr	pluck_char_choose_a_line
	rts

*********************************
* Pluck - Collated non-zero lines
*********************************

pluck_collated_lines:

	RZB	PLUCK_LINES

pluck_end_collated_lines:

**********************************
* Whether to rebuild our collation
**********************************

collation_needs_rebuilding:

	FCB	255

collation_number_of_lines:

	FCB	0

********************************
* Pluck - Collate non-zero lines
*
* Inputs: None
*
* Output:
* A = Number of non-zero lines
********************************

pluck_collate_non_zero_lines:

	lda	collation_needs_rebuilding
	beq	pluck_use_collation

	bsr	pluck_collate_non_zero_lines_2
	clr	collation_needs_rebuilding	; Probably don't need to
	sta	collation_number_of_lines	; rebuild next time

	rts					; Return A

pluck_use_collation:

	lda	collation_number_of_lines	; Return A
	rts

********************************
* Pluck - Collate non-zero lines
*
* Inputs: None
*
* Output:
* A = Number of non-zero lines
********************************

pluck_collate_non_zero_lines_2:

	ldx	#pluck_line_counts
	ldu	#pluck_collated_lines
	clra
	clrb

_pluck_collate_loop:
	cmpx	#pluck_line_counts_end
	bhs	_pluck_collate_finished

	tst	,x+
	beq	_skip_collation

	stb	,u+
	inca

_skip_collation:
	incb
	bra	_pluck_collate_loop

_pluck_collate_finished:
	rts

******************************
* Pluck - Choose a line
*
* Inputs:
* A = Number of collated lines
*
* Output:
* A = Chosen line number
******************************

pluck_char_choose_a_line:

	pshs	a
	jsr	get_random	; Random number in B
	puls	a

	mul			; A is a random number from 0 to no. lines

	ldx	#pluck_collated_lines
	lda	a,x		; Get the actual line number

	ldx	#pluck_line_counts
	dec	a,x		; There'll be one less character after this
	bne	_skip_cache_dirtying

	clr	cached_pluck_lines_empty_is_good ; Dirty this cache
	ldb	#1				 ; And rebuild collation
	stb	collation_needs_rebuilding	 ; next time

_skip_cache_dirtying:
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

	pshs	a
	jsr	get_pluck_data_end
	puls	a
	pshs	x		;,S = End of pluck data

	jsr	get_end_of_line	; X = Screen position (going backwards)

	lda	#GREEN_BOX	; A = Green box (space)

	bra	pluck_get_char_2

*******************************************************
* Pluck - Get char 2
*
* Inputs:
*  A = Green box (space character)
*  X = Screen position to search (backwards) from
* ,S = End of pluck data
*
* Outputs:
*  X = Pointer to screen position of pluckable character
*******************************************************

pluck_get_char_2:

	cmpa	,-x		; Go backwards until we find a non-space
	beq	pluck_get_char_2

	ldu	#plucks_data+2	; This checks whether the found char is
				; already being plucked
_pluck_a_char_check:
	cmpx	,u
	beq	pluck_get_char_2

	leau	4,u
	cmpu	,s
	blo	_pluck_a_char_check

	leas	2,s		; Return X

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

************************************************************
* Pluck - Register
*
* Input:
* X = Screen position of character being plucked
*
* Outputs:
* X = (Unchanged) Screen position of character being plucked
************************************************************

pluck_register:

	tfr	x,u
	ldx	spare_slot	; Get the value from pluck_find_a_spare_slot
	ldb	,u		; B = the character being plucked
				; X is the slot
				; U is the screen position
	lda	#PLUCK_PHASE_TURN_WHITE	; This is our new phase
	sta	,x+		; Store our new phase
	stb	,x+		; the character
	stu	,x		; And where it is

	tfr	u,x		; Return X

	rts

*********************
* Place white box
*
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

	ldx	#pop_sound
	ldu	#pop_sound_end
	jsr	play_sound	; Play the pluck noise

	rts

*****************
* Process pluck 2
*
* Inputs: None
* Outputs: None
*****************

process_pluck_2:

	ldu	#plucks_data
	jsr	get_pluck_data_end
	pshs	x		; ,S = End of pluck data

_pluck_do_each_pluck:
	lda	,u
	beq	_no_pluck_happening	; This will run faster
	ldb	1,u
	ldx	2,u

	pshs	u
	bsr	pluck_do_one_pluck
	puls	u

_no_pluck_happening:
	leau	4,u
	cmpu	,s
	blo	_pluck_do_each_pluck

	leas	2,s
	rts

**********************
* Pluck - Do one pluck
*
* Inputs:
* A = Phase
* B = Character
* X = Screen position
* U = Pluck data
*
* Outputs: None
**********************

pluck_do_one_pluck:

;	cmpa	#PLUCK_PHASE_NOTHING	; tsta
;	beq	pluck_phase_0	; Nothing happening

	cmpa	#PLUCK_PHASE_TURN_WHITE
	beq	pluck_phase_1	; We are white

	cmpa	#PLUCK_PHASE_PLAIN
	beq	pluck_phase_2	; We are plain

	bra	pluck_phase_3	; We are pulling

*********************
* Pluck phase 0
* Inputs:
* A = Phase
* B = Character
* X = Screen position
* U = Pluck data
*
* Outputs: None
*********************

pluck_phase_0:

	rts			; Phase nothing, do nothing

*********************
* Pluck phase 1
*
* Inputs:
* A = Phase
* B = Character
* X = Screen position
* U = Pluck data
*
* Outputs: None
*********************

pluck_phase_1:

	lda	#PLUCK_PHASE_PLAIN
	sta	,u
	rts

*********************
* Pluck phase 2
*
* Inputs:
* A = Phase
* B = Character
* X = Screen position
* U = Pluck data
*
* Outputs: None
*********************

pluck_phase_2:

	stb	,x		; Show the plain character

	lda	#PLUCK_PHASE_PULLING	; Go to phase 3
	sta	,u

	rts

*********************
* Pluck phase 3
*
* Inputs:
* A = Phase
* B = Character
* X = Screen position
* U = Pluck data
*
* Outputs: None
*********************

pluck_phase_3:

	lda	#GREEN_BOX
	sta	,x+		; Erase the drawn character

	pshs	b,x,u
	tfr	x,d
	jsr	is_d_divisible_by_32
	tsta
	puls	b,x,u		; Does not affect condition codes
	bne	pluck_phase_3_ended

	stb	,x		; Draw it in the next column to the right
	stx	2,u		; Update position in plucks_data

	rts

*********************
* Pluck phase 3 ended
*
* Inputs:
* A = Phase
* B = Character
* X = Screen position
* U = Pluck data
*
* Outputs: None
*********************

number_of_plucked_chars:

	RZB	1

pluck_phase_3_ended:		; Character has gone off the right side

	lda	#PLUCK_PHASE_NOTHING
	sta	,u		; This slot is now empty

	clr	cache_slots_being_used	; We must count the slots again

	lda	number_of_plucked_chars
	inca
	sta	number_of_plucked_chars

	cmpa	simultaneous_plucks
	beq	_increase_plucks

	rts

_increase_plucks:

	cmpa	#MAX_SIMULTANEOUS_PLUCKS
	beq	_no_increase

	inc	simultaneous_plucks
	clr	cached_pluck_data_end_is_good	; Trash this cache
	clr	number_of_plucked_chars

_no_increase:
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

get_random:

	lda	#USE_DEEKS_CODE
	beq	get_random_cavell
	bra	get_random_conner

********************************
* Pseudo-random number generator
*
* Inputs: None
* Output:
* D = Random(ish) number
********************************

* I found these values through simple experimentation.
* This RNG could be improved on.

cavell_seed:

	FCB	0xBE
	FCB	0xEF

get_random_cavell:

	ldd	cavell_seed
	mul
	addd	#3037
	std	cavell_seed
	rts

********************************
* Pseudo-random number generator
*
* Inputs: None
* Output:
* D = Random(ish) number
********************************

; This code was written by Sean Conner (Deek) in June 2025 during a
; discussion on Discord, and then modified by me

conner_seed:

	FCB	0xBE
	FCB	0xEF

get_random_conner:

	ldd	conner_seed
	lsra
	rorb
	bcc	get_random_no_feedback
	eora	#$B4

get_random_no_feedback:
	std	conner_seed
	rts

*********************
* Joke startup screen
*
* Inputs: None
* Outputs: None
*********************

joke_startup_screen:

	jsr	clear_screen			; Just clear the screen

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

MESSAGES_END	EQU	255

joke_startup_messages:

	FCV	"INCORPORATING CLEVER IDEAS...",0
	FCV	"%DONE",0,0
	FCV	"UTILIZING MAXIMUM PROGRAMMING",0
	FCV	"SKILL...% DONE",0,0
	FCV	"INCLUDING EVER SO MANY",0
	FCV	"AWESOME EFFECTS...% DONE",0,0
	FCV	"READYING ALL YOUR FAVOURITE",0
	FCV	"DEMO CLICHES...% DONE",0,0
	FCV	"STARTING THE SHOW...%%%%%%"

	FCB	MESSAGES_END

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

	ldu	#TEXTBUF

_display_messages_loop:
	lda	,x+
	beq	display_messages_next_line
	cmpa	#'%' + 64
	beq	display_messages_big_pause
	cmpa	#MESSAGES_END
	beq	_display_messages_end
	sta	,u+

	bsr	display_messages_play_sound
	bsr	display_messages_pause
	tsta
	beq	_display_messages_loop	; If branch is taken,
					; user has not skipped
	bra	_display_messages_skip

**********************************
* Display messages - Exit routines
*
* Inputs: None
*
* Outputs:
* A = 0 Normal termination
* A = 1 User wants to skip
**********************************

_display_messages_skip:
	lda	#1		; User wants to skip
	rts

_display_messages_end:
	clra
	rts

************************************
* Display messages - Next line
*
* Inputs:
* X = Messages position
* U = Text buffer position
*
* Outputs:
* X = (Unchanged) Messages position
* U = (Updated) Text buffer position
************************************

display_messages_next_line:

	pshs	x
	tfr	u,x
	bsr	move_to_next_line
	tfr	x,u
	puls	x

	pshs	x,u
	lda	#5
	jsr	wait_frames
	tsta
	puls	x,u
	bne	_display_messages_skip
	bra	_display_messages_loop

***************************************
* Move to next line
*
* Input:
* X = Screen position pointer
*
* Output:
* X = (Updated) Screen position pointer
***************************************

move_to_next_line:

	tfr	x,d
	addd	#COLS_PER_LINE
	andb	#0b11100000
	tfr	d,x

	rts

***************************************
* Display messages - Big pause
*
* X = Messages position
* U = Text buffer position
*
* Outputs:
* X = (Unmodified) Messages position
* U = (Unmodified) Text buffer position
***************************************

display_messages_big_pause:

	pshs	x,u
	lda	#WAIT_PERIOD
	jsr	wait_frames
	tsta
	puls	x,u
	beq	_display_messages_loop

	lda	#1		; User wants to skip
	rts

***************************************
* Display messages - Pause
*
* X = Messages position
* U = Text buffer position
*
* Outputs:
* X = (Unmodified) Messages position
* U = (Unmodified) Text buffer position
***************************************

display_messages_pause:

	pshs	x,u
	lda	#5
	jsr	wait_frames
	puls	x,u
	rts

***************************************
* Display messages - Play sound
*
* Inputs:
* A = Character being displayed
* X = Messages position
* U = Text buffer position
*
* Outputs:
* X = (Unmodified) Messages position
* U = (Unmodified) Text buffer position
***************************************

display_messages_play_sound:

	cmpa	#GREEN_BOX
	beq	_display_messages_skip_sound

	pshs	x,u
	ldx	#type_sound
	ldu	#type_sound_end
	jsr	play_sound		; Play the typing noise
	puls	x,u
					; fallthrough
_display_messages_skip_sound:
	rts

************************************
* Switch IRQ and FIRQ interrupts off
*
* Inputs: None
* Outputs: None
************************************

switch_off_irq_and_firq:

	orcc	#0b01010000	; Switch off IRQ and FIRQ interrupts

	rts

***********************************
* Switch IRQ and FIRQ interrupts on
*
* Inputs: None
* Outputs: None
***********************************

switch_on_irq_and_firq:

	andcc	#0b10101111	; Switch IRQ and FIRQ interrupts back on

	rts

*****************************
* Is there a spare sound slot
*
* Inputs: None
* Output:
* A = (Non-zero) Yes
* A = 0 No
*****************************

is_there_a_spare_sound_slot:

	ldx	smp_1+1
	cmpx	end_1+1
	beq	_spare_slot

	ldx	smp_2+1
	cmpx	end_2+1
	beq	_spare_slot

	ldx	smp_3+1
	cmpx	end_3+1
	beq	_spare_slot

	ldx	smp_4+1
	cmpx	end_4+1
	beq	_spare_slot

	clra
	rts

_spare_slot:
	lda	#1
	rts

*******************************
* Play a sound sample
*
* Inputs:
* X = The sound data
* U = The end of the sound data
*
* Outputs: None
*******************************

play_sound:

	ldy	smp_1+1
	cmpy	end_1+1
	bne	_slot_2

* This code was modified from code written by Simon Jonassen

	stx	smp_1+1		; This is self-modifying code
	stu	end_1+1

* End of code modified from code written by Simon Jonassen

	rts

*******************************
* Slot 2
*
* Inputs:
* X = The sound data
* U = The end of the sound data
*
* Outputs: None
*******************************

_slot_2:
	ldy	smp_2+1
	cmpy	end_2+1
	bne	_slot_3

* This code was modified from code written by Simon Jonassen

	stx	smp_2+1		; This is self-modifying code
	stu	end_2+1

* End of code modified from code written by Simon Jonassen

	rts

*******************************
* Slot 3
*
* Inputs:
* X = The sound data
* U = The end of the sound data
*
* Outputs: None
*******************************

_slot_3:
	ldy	smp_3+1
	cmpy	end_3+1
	bne	_slot_4

* This code was modified from code written by Simon Jonassen

	stx	smp_3+1		; This is self-modifying code
	stu	end_3+1

* End of code modified from code written by Simon Jonassen

	rts

_slot_4:

	stx	smp_4+1		; This is self-modifying code
	stu	end_4+1
	rts

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

TEXT_GRAPHIC_END	EQU	255

display_text_graphic:

	pshs	b,x
	jsr	get_screen_position
	puls	b,u			; U = graphics data

_display_text_graphic_loop:
        lda     ,u+
        beq     text_graphic_new_line
        cmpa    #TEXT_GRAPHIC_END
        beq	_display_text_graphic_finished
        sta     ,x+
        bra     _display_text_graphic_loop

_display_text_graphic_finished:
	rts

*******************************
* Text graphic new line
*
* Inputs:
* B = Column number
* X = Screen position
* U = Message
*
* Outputs:
* B = (Unchanged) Column number
* X = (Updated)   Screen position
* U = (Unchanged) Message
*******************************

text_graphic_new_line:

	pshs	b,u
	jsr	move_to_next_line
	puls	b,u

	leax	b,x
	bra	_display_text_graphic_loop

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

	rts

***************
* Loading text
*
* Inputs: None
* Outputs: None
***************

print_loading_text:

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
	FCB	TEXT_GRAPHIC_END

baby_elephant_end:

*********************
* Turn off interrupts
*
* Inputs: None
* Outputs: None
*********************

turn_off_interrupts:

	jsr     switch_off_irq

* This code is modified from code written by Simon Jonassen

	lda	PIA0AC		; Turn off HSYNC interrupt
	anda	#0b11111110
	sta	PIA0AC

	lda	PIA0AD		; Acknowledge any outstanding
				; interrupt request

* End of code modified from code written by Simon Jonassen

	jsr     switch_on_irq

	rts

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

	lda	decb_irq_service_instruction
	sta	IRQ_INSTRUCTION

	ldx	decb_irq_service_routine
	stx	IRQ_HANDLER

	rts

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

*************************************
* Here is our raw data for our sounds
*************************************

pop_sound:

	INCLUDEBIN "Sounds/Pop/Pop.raw"

pop_sound_end:

type_sound:

	INCLUDEBIN "Sounds/Type/Type.raw"

type_sound_end:
