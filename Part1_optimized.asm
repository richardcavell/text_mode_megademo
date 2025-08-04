* This is Part 1 of Text Mode Demo
* by Richard Cavell
* June - August 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This demo part is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 16K of RAM
*
* Parts of this code were written by Simon Jonassen (The Invisible Man)
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

* Between each section, wait this number of frames

WAIT_PERIOD	EQU	25

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

start:

*************************
* Text buffer information
*************************

TEXTBUF		EQU	$400	; There's only one text screen
TEXTBUFSIZE	EQU	$200
TEXTBUFEND	EQU	(TEXTBUF+TEXTBUFSIZE)

BACKBUF		EQU	back_buffer	; We're double-buffering
BACKBUFEND	EQU	(BACKBUF+TEXTBUFSIZE)

COLS_PER_LINE	EQU	32
TEXT_LINES	EQU	16

LOWER_LEFT_CORNER	EQU	$5E0
LOWER_RIGHT_CORNER	EQU	$5FF

BOTTOM_LINE	EQU	(TEXT_LINES-1)

******************
* Setup backbuffer
*
* Inputs: None
* Outputs: None
******************

	ldx	#TEXTBUF
	ldu	#BACKBUF

_setup_loop:
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++

	cmpx	#TEXTBUFEND
	blo	_setup_loop

***************************
* Set DP register for HSYNC
*
* Inputs: None
* Outputs: None
***************************

* This code was written by Simon Jonassen and modified by me

	orcc	#0b01010000	; Switch off IRQ and FIRQ interrupts
	lda	#irq_service_routine/256
	tfr	a,dp
	SETDP	irq_service_routine/256
	andcc	#0b10101111	; Switch IRQ and FIRQ interrupts back on

* End of code written by Simon Jonassen and modified by me

*********************************
* Install our IRQ service routine
*
* Inputs: None
* Outputs: None
*********************************

IRQ_INSTRUCTION	EQU	$10C
IRQ_HANDLER	EQU	$10D

	orcc	#0b00010000		; Switch off IRQ interrupts

	lda	IRQ_INSTRUCTION		; Should be JMP (extended)
	sta	decb_irq_service_instruction

	ldx	IRQ_HANDLER			; Load the current vector
	stx	decb_irq_service_routine	; We could call it at the end
						; of our own handler

	lda	#$0e			; DP JMP
	sta	IRQ_INSTRUCTION		; Shaves off 1 byte

	lda	#irq_service_routine&255
	sta	IRQ_HANDLER

; The last byte stays the same

	andcc	#0b11101111		; Switch IRQ interrupts back on

*********************
* Turn off disk motor
*
* Inputs: None
* Outputs: None
*********************

DSKREG	EQU	$FF40

	clra
	sta	DSKREG		; Turn off disk motor

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

*******************
* Set audio port on
*
* Inputs: None
* Outputs: None
*******************

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

********************
* Turn on interrupts
********************

	orcc	#0b01010000	; Switch off IRQ and FIRQ interrupts

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

	andcc	#0b10101111	; Switch IRQ and FIRQ interrupts back on




	jsr	display_skip_message
	jsr	pluck_the_screen		; First section
	jsr	joke_startup_screen		; Second section
	jsr	loading_screen
	jsr	print_loading_text
	jsr	turn_off_interrupts		; Go back to what BASIC uses

	jsr	restore_basic_irq_service_routine
	jsr	zero_dp_register		; Zero the DP register

	ldd	#0
	rts		; Return to Disk Extended Color BASIC

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

******************************************************
* Variables that are relevant to vertical blank timing
******************************************************

waiting_for_vblank:

	RZB	1		; The interrupt handler reads this

vblank_happened:

	RZB	1		; and sets this

**********************************************
* Variables relating to DECB's own IRQ handler
**********************************************

decb_irq_service_instruction:

	RZB	1		; Should be JMP (extended)

decb_irq_service_routine:

	RZB	2

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
	beq	_1_is_silent

	lda	,x+		; Get the next byte of data
	stx	smp_1+1		; Self-modifying code here

_1_is_silent:

smp_2:	ldx	#0
end_2:	cmpx	#0
	beq	_2_is_silent

	adda	,x+
	stx	smp_2+1

_2_is_silent:

smp_3:	ldx	#0
end_3:	cmpx	#0
	beq	_3_is_silent

	adda	,x+
	stx	smp_3+1

_3_is_silent:

smp_4:	ldx	#0
end_4:	cmpx	#0
	beq	_4_is_silent

	adda	,x+
	stx	smp_4+1

_4_is_silent:
	sta	AUDIO_PORT	; and shove it into the audio port

	lda	PIA0AD		; Acknowledge HSYNC interrupt
	rti

* End of code that was written by Simon Jonassen and modified by me

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

	ldx	#TEXTBUF
	ldu	#BACKBUF

_copy_loop:	; Copy the backbuffer to the text screen

; This code was contributed by Simon Jonassen

        pulu    d,y
        std     ,x
        sty     2,x
        pulu    d,y
        std     4,x
        sty     6,x
        pulu    d,y
        std     8,x
        sty     10,x

        pulu    d,y
        std     12,x
        sty     14,x
        pulu    d,y
        std     16,x
        sty     18,x
        pulu    d,y
        std     20,x
        sty     22,x

        pulu    d,y
        std     24,x
        sty     26,x
        pulu    d,y
        std     28,x
        sty     30,x

; End of code contributed by Simon Jonassen

        leax    COLS_PER_LINE,x
        cmpx    #TEXTBUFEND
        blo     _copy_loop

_dropped_frame:
	lda	PIA0BD			; Acknowledge interrupt
	rti

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

	leau	,x		; Credit to Simon Jonassen for this line

	clrb
	bsr	get_screen_position		; X = Screen position

_display_message_loop:
	cmpx	#BACKBUFEND
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

;   X = BACKBUF + A * COLS_PER_LINE + B

	stb	dval+1		; This was added by Simon Jonassen
				; and refined by me
	ldx	#BACKBUF
	ldb	#COLS_PER_LINE
	mul
	leax	d,x

dval:	ldb	#$00		; And this
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

pluck_line_counts:

	RZB PLUCK_LINES			; 15 zeroes

pluck_line_counts_end:

*************
* Plucks data
*************

MAX_SIMULTANEOUS_PLUCKS	EQU	2

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

; Count the number of characters on each line of the screen

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

	ldx	#BACKBUF
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

;	pshs	x,u		; Simon Jonassen contributed the semicolons
	tfr	x,d
	bsr	is_d_divisible_by_32
	tsta
;	puls	x,u		; Does not affect Condition Codes
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

_wait_for_vblank_and_check_for_skip_loop:
	bsr	poll_keyboard
	tsta
	bne	_skip

	lda	vblank_happened
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

	clra		; Debug mode is off, so exit normally
	rts

_wait_for_vblank_skip:
	lda	#1	; User wants to skip
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

pluck_check_empty_slots:

	bsr	pluck_check_empty_slots_2	; Return what this returns
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

	ldx	#plucks_data_end

	stx	oldx+1		; Simon Jonassen contributed this line

	ldx	#plucks_data

_pluck_check_data:
	lda	,x
	bne	_pluck_check_data_not_empty
	leax	4,x
oldx	cmpx	#$0000		; and this one
	blo	_pluck_check_data

	lda	#1			; There are no plucks happening
	rts

_pluck_check_data_not_empty:
	clra				; There are plucks happening
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

	ldx	#plucks_data_end
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
;	clra
;	clrb
	ldd	#$0000	; Simon Jonassen contributed this line

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

	sta	olda1+1
	jsr	get_random	; Random number in B
olda1:	lda	#$00

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

	sta	olda2+1		; Simon Jonassen contributed this line
	ldx	#plucks_data_end
olda2:	lda	#$00		; and this one
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

;	tfr	x,u
	leau	,x		; Contributed by Simon Jonassen
	ldx	spare_slot	; Get the value from pluck_find_a_spare_slot
	ldb	,u		; B = the character being plucked
				; X is the slot
				; U is the screen position
	lda	#PLUCK_PHASE_TURN_WHITE	; This is our new phase
;	sta	,x+		; Store our new phase
;	stb	,x+		; the character
	std	,x++		; SJ contributed this line as well
	stu	,x		; And where it is

;	tfr	u,x		; Return X
	leax	,u		; SJ contributed this line
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
	ldx	#plucks_data_end
	pshs	x		; ,S = End of pluck data

_pluck_do_each_pluck:
	lda	,u
	beq	_no_pluck_happening	; This will run faster
	ldb	1,u
	ldx	2,u

;	pshs	u		; Simon Jonassen contributed this
	stu	oldu+1
	bsr	pluck_do_one_pluck
;	puls	u
oldu:	ldu	#$0000		; and this

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

pluck_phase_3_ended:		; Character has gone off the right side

	lda	#PLUCK_PHASE_NOTHING
	sta	,u		; This slot is now empty

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

	ldu	#BACKBUF

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

;	pshs	x
	stx	oldx2+1		; Simon Jonassen contributed this line
	tfr	u,x
	bsr	move_to_next_line
	tfr	x,u
oldx2:	ldx	#$0000		; and this one
;	puls	x

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

	ldx	#BACKBUF
	ldd	#(GREEN_BOX << 8 | GREEN_BOX)	; Two green boxes

_clear_screen_loop:
	std	,x++
	std	,x++
	std	,x++
	std	,x++

	cmpx	#BACKBUFEND		; Finish in the lower-right corner
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
	lda	#1
	jsr	wait_frames

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

	orcc	#0b00010000		; Switch off IRQ interrupts

* This code is modified from code written by Simon Jonassen

	lda	PIA0AC		; Turn off HSYNC interrupt
	anda	#0b11111110
	sta	PIA0AC

	lda	PIA0AD		; Acknowledge any outstanding
				; interrupt request

* End of code modified from code written by Simon Jonassen

	andcc	#0b11101111		; Switch IRQ interrupts back on

	rts

*************************************
* Restore BASIC's IRQ service routine
*
* Inputs: None
* Outputs: None
*************************************

restore_basic_irq_service_routine:

	orcc	#0b00010000		; Switch off IRQ interrupts
	bsr	restore_irq_handler
	andcc	#0b11101111		; Switch IRQ interrupts back on

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

**************************
* Our backbuffer goes here
**************************

	align	COLS_PER_LINE

back_buffer:

	RZB	512,GREEN_BOX

back_buffer_end:
