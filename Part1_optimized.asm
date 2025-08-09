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

* The sound Pop.raw is from Mouth_pop.ogg by Cori from Wikimedia Commons
* https://commons.wikimedia.org/wiki/File:Mouth_pop.ogg
* The sound Type.raw is from Modelm.ogg by Cpuwhiz13 from Wikimedia Commons
* https://commons.wikimedia.org/wiki/File:Modelm.ogg
*
* The ASCII art of the baby elephant is by Shanaka Dias at asciiart.eu

*************************
* EQUATES
*************************
* Between each section, wait this number of frames
WAIT_PERIOD	EQU	25
*************************
* Text buffer information
*************************
TEXTBUF		EQU	$400	; This is the output text screen
TEXTBUFSIZE	EQU	$200
TEXTBUFEND	EQU	(TEXTBUF+TEXTBUFSIZE)
BACKBUF		EQU	back_buffer	; We're double-buffering
BACKBUFEND	EQU	(BACKBUF+TEXTBUFSIZE)
COLS_PER_LINE	EQU	32
TEXT_LINES	EQU	16
BOTTOM_LINE	EQU	(TEXT_LINES-1)


IRQ_INSTRUCTION	EQU	$10C
IRQ_HANDLER	EQU	$10D

DSKREG	EQU	$FF40
*****************************
* PIA memory-mapped registers
*****************************

PIA0AD	EQU	$FF00
PIA0AC	EQU	$FF01
PIA0BD	EQU	$FF02
PIA0BC	EQU	$FF03

AUDIO_PORT  	EQU	$FF20		; (the top 6 bits)
DDRA		EQU	$FF20
PIA2_CRA	EQU	$FF21
AUDIO_PORT_ON	EQU	$FF23		; Port Enable Audio (bit 3)
*****************************

TEXT_GRAPHIC_END	EQU	255

* Pluck variables
*****************

PLUCK_LINES	EQU	(TEXT_LINES-1)	; The bottom line of
					; the screen is for
					; our skip message

GREEN_BOX	EQU	$60		; These are MC6847 codes
WHITE_BOX	EQU	$CF

*************
* Plucks data
*************

MAX_SIMULTANEOUS_PLUCKS	EQU	2

; The structure of an entry in plucks_data is:
; phase     (1 byte),
; character (1 byte),
; position  (2 bytes)

PLUCK_PHASE_NOTHING	EQU	0
PLUCK_PHASE_TURN_WHITE	EQU	1
PLUCK_PHASE_PLAIN	EQU	2
PLUCK_PHASE_PULLING	EQU	3

*****************************
* Define POLCAT and BREAK_KEY
*****************************

; POLCAT is a pointer to a pointer

POLCAT		EQU	$A000

BREAK_KEY	EQU	3

MESSAGES_END	EQU	255

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

************************************
* Switch off IRQ and FIRQ interrupts
************************************

	orcc	#0b01010000	; Switch off IRQ and FIRQ interrupts
	dec	$71		;make any reset COLD

******************
* Setup backbuffer
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
***************************

* This code was written by Simon Jonassen and modified by me

	lda	#irq_service_routine/256
	tfr	a,dp
	SETDP	irq_service_routine/256

* End of code written by Simon Jonassen and modified by me

*********************************
* Install our IRQ service routine
*
* Inputs: None
* Outputs: None
*********************************

	lda	IRQ_INSTRUCTION		; Should be JMP (extended ($7e))
	sta	decb_irq_service_instruction

	ldx	IRQ_HANDLER			; Load the current vector
	stx	decb_irq_service_routine	; We could call it at the end
						; of our own handler

	lda	#$0e			; DP JMP
	sta	IRQ_INSTRUCTION		; Shaves off 1 byte and cycle !!

	ldd	#(irq_service_routine&255)*256+0
	std	IRQ_HANDLER

*********************
* Turn off disk motor
*********************

	clra
	sta	DSKREG		; Turn off disk motor

*********************
* Turn 6-bit audio on
*********************

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

**************************************************
* Display skip message at the bottom of the screen
*
* Inputs: None
* Outputs: None
**************************************************

	ldu	#skip_message
	ldx	#BACKBUF+PLUCK_LINES*COLS_PER_LINE

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

**************************************
* Turn IRQ and FIRQ interrupts back on
**************************************

	andcc	#0b10101111	; Switch IRQ and FIRQ interrupts back on

	jsr	pluck_the_screen		; First section

*********************
* Joke startup screen
*********************

	ldx	#BACKBUF
	ldd	#(GREEN_BOX << 8 | GREEN_BOX)	; Two green boxes

_clear_screen_loop:
	std	,x++
	std	,x++
	std	,x++
	std	,x++

	cmpx	#BACKBUFEND		; Finish in the lower-right corner
	blo	_clear_screen_loop

	lda	#WAIT_PERIOD
	jsr	wait_frames			; Wait a certain no of frames

	ldx	#joke_startup_messages
	jsr	display_messages
	tsta
	bne	_skip_joke_startup

	lda	#WAIT_PERIOD
	jsr	wait_frames			; Wait a certain no of frames

_skip_joke_startup:

****************
* Loading screen
****************

	ldx	#BACKBUF
	ldd	#(GREEN_BOX << 8 | GREEN_BOX)	; Two green boxes

_clear_screen_loop2:
	std	,x++
	std	,x++
	std	,x++
	std	,x++

	cmpx	#BACKBUFEND		; Finish in the lower-right corner
	blo	_clear_screen_loop2

	lda	#WAIT_PERIOD
	jsr	wait_frames

***********************************
* Display the baby elephant graphic
***********************************

display_text_graphic:

	ldu	#baby_elephant
	ldx	#BACKBUF+COLS_PER_LINE

_display_text_graphic_loop:
        lda     ,u+
        beq     text_graphic_new_line
        cmpa    #TEXT_GRAPHIC_END
        beq	_display_text_graphic_finished
        sta     ,x+
        bra     _display_text_graphic_loop

text_graphic_new_line:

	tfr	x,d
	addd	#32
	andb	#%11100000
	tfr	d,x

	bra	_display_text_graphic_loop

_display_text_graphic_finished:

********************
* Print loading text
********************

	ldx	#BACKBUF+15*COLS_PER_LINE+11

	ldd	#"LO"
	std	,x
	ldd	#"AD"
	std	2,x
	ldd	#"IN"
	std	4,x
	ldd	#'G'*256+'.'+64
	std	6,x
	ldd	#(('.'+64)*256)+'.'+64
	std	8,x

	lda	#1
	jsr	wait_frames

*********************
* Turn off interrupts
*********************

	orcc	#0b00010000		; Switch off IRQ interrupts

* This code is modified from code written by Simon Jonassen

	lda	PIA0AC		; Turn off HSYNC interrupt
	anda	#0b11111110
	sta	PIA0AC

	lda	PIA0AD		; Acknowledge any outstanding
				; interrupt request

* End of code modified from code written by Simon Jonassen

*************************************
* Restore BASIC's IRQ service routine
*
* Inputs: None
* Outputs: None
*************************************

	lda	decb_irq_service_instruction
	sta	IRQ_INSTRUCTION

	ldx	decb_irq_service_routine
	stx	IRQ_HANDLER

	andcc	#0b11101111		; Switch IRQ interrupts back on

**************************************
* Zero the DP register and return zero
**************************************

	ldd	#0
	tfr	a, dp

	rts		; Return to Disk Extended Color BASIC

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

	align 256	; All the variables should be accessible in direct mode

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

*************************************
* Used by our random number generator
*************************************

conner_seed:

	FCB	0xBE
	FCB	0xEF

************
* Pluck data
************

pluck_line_counts:

	RZB PLUCK_LINES			; 15 zeroes

pluck_line_counts_end:

plucks_data:

	RZB	MAX_SIMULTANEOUS_PLUCKS * 4	; Reserve 4 bytes per pluck

plucks_data_end:

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

	ldd	#$0001			; This code written by Simon
	std	waiting_for_vblank	;    (back to back vars)

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

skip_message:

	FCV	"  PRESS SPACE TO SKIP ANY PART  "
	FCB	0

******************
* Pluck the screen
*
* Inputs: None
* Outputs: None
******************

pluck_the_screen:

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
	lda	#GREEN_BOX
	cmpa	,x+
	beq	_skip_count

	inc	,u		; Count non-spaces only

_skip_count:
	tfr	x,d
	andb	#0b00011111
	bne	_no_increment

	leau	1,u

_no_increment:
	cmpu	#pluck_line_counts_end
	blo	_pluck_count_loop

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

	ldx	#plucks_data
	tst	,x
	bne	_pluck_screen_not_empty		; Only 2 plucks
	tst	4,x				; can happen
	bne	_pluck_screen_not_empty		; at once
	bra	pluck_are_lines_empty	; Return whatever this returns

_pluck_screen_not_empty:
	clra				; Screen is not clear
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
cached_pluck_lines_empty:

	RZB	1

cached_pluck_lines_empty_is_good:

	RZB	1

pluck_are_lines_empty:

	lda	cached_pluck_lines_empty_is_good
	bne	_return_cache

	bsr	pluck_are_lines_empty_2
	ldb	#1
	std	cached_pluck_lines_empty		;back 2 back vars - simon
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

	ldx	#plucks_data
	lda	,x
	beq	_found_spare

	ldx	#plucks_data+4
	lda	,x
	beq	_found_spare

	clra
	rts

_found_spare:
	lda	#1	; Return X as well
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
	bsr	pluck_get_char

************************************************
* Pluck - Pluck character
*
* Input:
* X = Screen position of character to be plucked
*
* Outputs:None
************************************************

pluck_char:

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

	leau	,x		; Contributed by Simon Jonassen
	ldx	spare_slot	; Get the value from pluck_find_a_spare_slot
	ldb	,u		; B = the character being plucked
				; X is the slot
				; U is the screen position
	lda	#PLUCK_PHASE_TURN_WHITE	; This is our new phase
	std	,x++		; SJ contributed this line as well
	stu	,x		; And where it is
	leax	,u		; SJ contributed this line

*********************
* Place white box
*********************

	lda	#WHITE_BOX
	sta	,x

	ldx	#pop_sound
	ldu	#pop_sound_end
	jsr	play_sound	; Play the pluck noise

_no_chars_left:
	rts		; No more unplucked characters left on the screen

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

	clr	collation_needs_rebuilding	; Probably don't need to
	sta	collation_number_of_lines	; rebuild next time

	rts					; Return A

pluck_use_collation:

	lda	collation_number_of_lines	; Return A
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

; This code was written by Sean Conner (Deek) in June 2025 during a
; discussion on Discord, and then modified by me

get_random:

	ldd	conner_seed
	lsra
	rorb
	bcc	get_random_no_feedback
	eora	#$B4

get_random_no_feedback:
	std	conner_seed

; End of code written by Sean Conner

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

	ldx	#BACKBUF
	inca	; Make X point to the right end of the line
	ldb	#COLS_PER_LINE
	mul
	leax	d,x

	lda	#GREEN_BOX	; A = Green box (space)
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

	cmpx	plucks_data+2		; This checks whether the found char is
	beq	pluck_get_char_2	; already being plucked

	cmpx	plucks_data+6
	beq	pluck_get_char_2

	rts

*****************
* Process pluck 2
*
* Inputs: None
* Outputs: None
*****************

process_pluck_2:

	ldu	#plucks_data

	lda	,u
	beq	_no_pluck_happening_1	; This will run faster
	ldb	1,u
	ldx	2,u

	bsr	pluck_do_one_pluck

_no_pluck_happening_1:
	ldu	#plucks_data+4

	lda	,u
	beq	_no_pluck_happening_2	; This will run faster
	ldb	1,u
	ldx	2,u

	bsr	pluck_do_one_pluck

_no_pluck_happening_2:

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

	cmpa	#PLUCK_PHASE_TURN_WHITE
	bne	plp2	; We are white
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
plp2	cmpa	#PLUCK_PHASE_PLAIN
	bne	pluck_phase_3	; We are plain


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
	stb	oldb+1

	tfr	x,d
	andb	#0b00011111	; Is it divisible by 32?
	beq	pluck_phase_3_ended

oldb	ldb	#$00
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

	ldd	#$100			; back to back vars (simon)
	std	waiting_for_vblank

_wait_for_vblank_and_check_for_skip_loop:
	jsr	[POLCAT]		; POLCAT is a pointer to a pointer
	cmpa	#' '			; Space bar
	beq	_wait_for_vblank_skip
	cmpa	#BREAK_KEY		; Break key
	beq	_wait_for_vblank_skip

	lda	vblank_happened
	beq	_wait_for_vblank_and_check_for_skip_loop

	clra		; A VBlank happened
	rts

_wait_for_vblank_skip:
	lda	#1	; User skipped
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

	cmpa	#GREEN_BOX
	beq	_display_messages_skip_sound

	pshs	x,u
	ldx	#type_sound
	ldu	#type_sound_end
	jsr	play_sound		; Play the typing noise
	puls	x,u

_display_messages_skip_sound:

	lda	#5
	jsr	wait_frames
	tsta
	beq	_display_messages_loop	; If branch is taken,
					; user has not skipped

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

	tfr	u,d
	addd	#32
	andb	#%11100000
	tfr	d,u

	lda	#5
	jsr	wait_frames
	tsta
	bne	_display_messages_skip
	bra	_display_messages_loop

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

	lda	#WAIT_PERIOD
	jsr	wait_frames
	tsta
	beq	_display_messages_loop
	lda	#1		; User wants to skip
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
	FCV	"READYING ALL YOUR FAVOURITE",0
	FCV	"DEMO CLICHES...% DONE",0,0
	FCV	"STARTING THE SHOW...%%%%%%"

	FCB	MESSAGES_END

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
