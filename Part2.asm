* This is Part 2 of Text Mode Demo
* by Richard Cavell
* June - August 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This demo part is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* Parts of this code were written by Simon Jonassen (The Invisible Man)
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by a number of other authors
* You can see here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
* Part of this code was written by Allen C. Huffman at Sub-Etha Software
* You can see it here:
* https://subethasoftware.com/2022/09/06/counting-6809-cycles-with-lwasm/
*
* The speech "RJFC Presents Text Mode Megademo" was created by this website:
* https://speechsynthesis.online/
* The voice is "Ryan"
*
* The song "Pop Corn" is by Gershon Kingsley. I don't know who created the
* arrangement that is used here. It was modified by Simon Jonassen and me.
*
* The ASCII art of the small creature is by Microsoft Copilot
* The big cat was done by Blazej Kozlowski at
* https://www.asciiart.eu/animals/birds-land
* Both graphics have been modified by me
* Animation of the small creature by me
*
*************************
* EQUATES
*************************

* Between each section, wait this number of frames

WAIT_PERIOD	EQU	25

*************************
* Text buffer information
*************************

TEXTBUF		EQU	$400	; We're not double-buffering in this part
TEXTBUFSIZE	EQU	$200	; so there's only one text screen
TEXTBUFEND	EQU	(TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE	EQU	32
TEXT_LINES	EQU	16

**************************
* Interrupt request vector
**************************

IRQ_INSTRUCTION EQU     $10C
IRQ_HANDLER     EQU     $10D

*****************************
* PIA memory-mapped registers
*****************************

PIA0AD          EQU     $FF00
PIA0AC          EQU     $FF01
PIA0BD          EQU     $FF02
PIA0BC          EQU     $FF03

AUDIO_PORT      EQU     $FF20           ; (the top 6 bits)
DDRA            EQU     $FF20
PIA2_CRA        EQU     $FF21
AUDIO_PORT_ON   EQU     $FF23           ; Port Enable Audio (bit 3)

DSKREG          EQU     $FF40

*****************************
* Define POLCAT and BREAK_KEY
*****************************

POLCAT          EQU     $A000           ; POLCAT is a pointer to a pointer

BREAK_KEY       EQU     3

*************************
* We need to mark the end
*************************

TEXT_END 	EQU     255

**************
* MC6847 Codes
**************

GREEN_BOX       EQU     $60
WHITE_BOX       EQU     $CF

***********************************

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

        orcc    #0b01010000     ; Switch off IRQ and FIRQ interrupts

        dec     $71             ; Make any reset COLD (Simon Jonassen)

*********************************
* Install our IRQ service routine
*********************************

        lda     IRQ_INSTRUCTION         ; Should be JMP (extended ($7e))
        sta     decb_irq_service_instruction

        ldx     IRQ_HANDLER                     ; Load the current vector
        stx     decb_irq_service_routine        ; We could call it at the end
                                                ; of our own handler

                ; DP JMP Shaves off 1 byte and cycle !!

        ldd     #$0E*256+(irq_service_routine&255)
        std     IRQ_INSTRUCTION

*********************************
* Set DP register for convenience
*********************************

	lda	#$FF
	tfr	a,dp
	SETDP	$FF

*********************
* Turn off disk motor
*********************

        clra
        sta     DSKREG          ; Turn off disk motor

*********************
* Turn 6-bit audio on
*********************

* This is modified by me from code written by Simon Jonassen

        lda     PIA0BC
        anda    #0b11110111
        sta     PIA0BC

        lda     PIA0AC
        anda    #0b11110111
        sta     PIA0AC

* End code modified from code written by Simon Jonassen

        lda     #128
        sta     AUDIO_PORT      ; Get rid of that click

* This code was modified from code written by Trey Tomes

        lda     AUDIO_PORT_ON
        ora     #0b00001000
        sta     AUDIO_PORT_ON   ; Turn on 6-bit audio

* End code modified from code written by Trey Tomes

************************
* Set DDRA bits to input
************************

* This code was written by other people, taken from
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0>
* and then modified by me

        ldb     PIA2_CRA
        andb    #0b11111011
        stb     PIA2_CRA

        lda     #0b11111100
        sta     DDRA

        orb     #0b00000100
        stb     PIA2_CRA

* End of code modified by me from code written by other people

*************************
* Turn on VSync interrupt
*************************

* This code was originally written by Simon Jonassen (The Invisible Man)
* and then modified by me

        lda     PIA0BC          ; Enable VSync interrupt
        ora     #3
        sta     PIA0BC
        lda     PIA0BD          ; Acknowledge any outstanding VSync interrupt

* End code modified by me from code written by Simon Jonassen

**************************
* Turn off HSync interrupt
**************************

        lda     PIA0AC          ; Turn off HSYNC interrupt
        anda    #0b11111110
        sta     PIA0AC

        lda     PIA0AD          ; Acknowledge any outstanding HSync
                                ; interrupt request

*******************************************
* Set DP register to our IRQ/variables page
*******************************************

	lda	#irq_service_routine/256
	tfr	a,dp
	SETDP	irq_service_routine/256

**************************************
* Turn IRQ and FIRQ interrupts back on
**************************************

        andcc   #0b10101111     ; Switch IRQ and FIRQ interrupts back on

	jsr	title_screen			; First section
	jsr	opening_credits			; Second section
	jsr	loading_screen

*********************
* Turn off interrupts
*********************

        orcc    #0b00010000             ; Switch off IRQ interrupts

* This code is modified from code written by Simon Jonassen

        lda     PIA0AC          ; Turn off HSYNC interrupt
        anda    #0b11111110
        sta     PIA0AC

        lda     PIA0AD          ; Acknowledge any outstanding
                                ; interrupt request

* End of code modified from code written by Simon Jonassen

*************************************
* Restore BASIC's IRQ service routine
*************************************

        lda     decb_irq_service_instruction
        sta     IRQ_INSTRUCTION

        ldx     decb_irq_service_routine
        stx     IRQ_HANDLER

        andcc   #0b11101111             ; Switch IRQ interrupts back on

**********************
* Zero the DP register
**********************

        clra
        tfr     a,dp

        rts             ; Return to Disk Extended Color BASIC

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

	align	256	; The interrupt service routine and all the variables
                        ; should be accessible in direct mode

*************************
* Our IRQ handler
*************************

irq_service_routine:

        lda     PIA0BC          ; Was it a VBlank or HSync?
        bmi     service_vblank  ; VBlank - go there

* If HSYNC, fallthrough to HSYNC handler

***************
* Service HSYNC
***************

music_on:
	lda	#$00
	beq	_skip_music

* This was written by Simon Jonassen and modified by me

;********************************************
; PLAYER ROUTINE
;********************************************
note            dec     <frames+1       ;
                bne     sum             ;
                dec     <frames
                bne     sum
                ldd     #$2c0           ;2c0    #of irq's to process before not>
                std     <frames
;********************************************
; SEQUENCER
;********************************************
;               opt     cc,ct

seq
oldu		ldu	#zix		;save pattern position
		cmpu	#endzix
		bne	plnote
		ldu	#zix
plnote		pulu	d,x		;load 2 notes from pattern
		stu	<oldu+1		;restore pattern position to start
		std	<freq+1		;store
		stx	<freq2+1
_skip_music:
		lda	$ff00
		rti

;********************************************
; NOTE ROUTINE
;********************************************

sum             ldd     #$0000          ;cumulative addition, we use A as inher>
freq            addd    #$0000          ;frequency to add
                std     <sum+1          ;store back to addition

sum2            ldd     #$0000          ;cumulative add (oscillator)
freq2           addd    #$0000          ;freq to add
                std     <sum2+1         ;and we store back to sum #2
                                        ;we have a value in A from prev addition
add             adda    <sum+1          ;add v1 to current A from summation
                rora                    ;/2 with possible carry to beat overloa>
                sta     $ff20           ;set the hardware

                lda     $ff00           ;ack hsync IRQ
                rti


frames          fdb     $2c0

* End of work done by Simon Jonassen and modified by me

****************
* Service VBlank
****************

service_vblank:

        lda     waiting_for_vblank      ; The demo is waiting for the signal
        beq     _dropped_frame

        clra                            ; No longer waiting
        sta     waiting_for_vblank

_dropped_frame:
        lda     PIA0BD                  ; Acknowledge interrupt
        rti

******************************************************
* DP VARIABLES (FOR SPEED)
******************************************************

***********************
* Vertical blank timing
***********************

waiting_for_vblank:

        RZB     1       ; The interrupt handler reads and clears this

**********************************************
* Variables relating to DECB's own IRQ handler
**********************************************

decb_irq_service_instruction:

        RZB     1       ; Should be JMP (extended)

decb_irq_service_routine:

        RZB     2

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

        lda     #1
        sta     waiting_for_vblank

_wait_for_vblank_and_check_for_skip_loop:
        jsr     [POLCAT]                ; POLCAT is a pointer to a pointer
        cmpa    #' '                    ; Space bar
        beq     _wait_for_vblank_skip
        cmpa    #BREAK_KEY              ; Break key
        beq     _wait_for_vblank_skip

        lda     waiting_for_vblank
        bne     _wait_for_vblank_and_check_for_skip_loop

_wait_for_vblank_skip:
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

        sta     st_a+1
        jsr     wait_for_vblank_and_check_for_skip
        tsta
        bne     _wait_frames_return     ; User wants to skip
st_a:   lda     #1
        deca
        bne     wait_frames

_wait_frames_return:                    ; Return A
        rts

**************
* Title screen
**************

title_screen:

* This code was written by Allen C. Huffman and modified by me and SJ

        ldd     #GREEN_BOX << 8 | GREEN_BOX
        tfr     d,x
        leay    ,x              ; SJ contributed this
        ldu     #TEXTBUFEND     ; (1 past end of screen)

loop48s:
        pshu    d,x,y
        cmpu    #TEXTBUF+2      ; Compare U to two bytes from start
        bgt     loop48s         ; If X!=that, GOTO loop48s
        std     -2,u            ; Final 2 bytes

* End of code written by Allen C. Huffman and modified by me and SJ

	lda	#WAIT_PERIOD
	jsr	wait_frames			; Wait a certain no of frames

	ldx	#title_screen_graphic
	jsr	display_text_graphic

	ldx	#title_screen_text
	jsr	print_text
	tsta
	bne	skip_title_screen

; Play the sound

	jsr	play_sound

; Then play the music

	jsr	musplay

; "Encase" the three text items

	lda	#5
	clrb
	jsr	encase_text
	tsta
	bne	skip_title_screen

	lda	#8
	ldb	#1
	jsr	encase_text
	tsta
	bne	skip_title_screen

	lda	#12
	clrb
	jsr	encase_text
	tsta
	bne	skip_title_screen

* Now flash the text white

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

* Now flash the whole screen

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

skip_title_screen:

	lda	#1
	sta	creature_blink_finished

	rts

***********************************
* Print text
*
* Inputs:
* X = Pointer to data block
*
* Outputs:
* A = 0          Successful
* A = (non-zero) User wants to skip
***********************************

print_text:

_print_text_loop:
	ldd	,x++

	stx	st_x+1
	jsr	text_appears
	tsta
	bne	_print_text_skipped

st_x:	ldx	#$0000
_find_zero:
	lda	,x+
	bne	_find_zero

	lda	#TEXT_END		; This marks the end of the text
					;   lines
	cmpa	,x			; Is that what we have?
	bne	_print_text_loop	; If not, then print the next line
					; If yes, then fall through
	clra
	rts

_print_text_skipped:
	lda	#1			; User has skipped this
	rts

*************************
* Play synthesized speech
*************************

play_sound:

; This routine was written by Simon Jonassen and slightly modified by me

	lda	sample
	sta	dasamp+1
	ldx	#sample+1	; %11111111
	ldu	#table1

****************************************
* UPPER NYBBLE PROCESSOR
****************************************

getnxt	lda	,x		; grab diff
	anda	#$F0		; mask lower bits
	lda	a,u
dasamp	adda	#0		; add diff to current sample
	sta	dasamp+1	; store as new current
	asla			; upper 6 bits
	asla			; for dac store
	sta	AUDIO_PORT	; out on dac

****************************************
* just a timing delay
****************************************

delay	ldb	#20
w1	decb
	bne	w1

****************************************
* LOWER NYBBLE PROCESSOR
****************************************

	lda	,x+		; grab diff and bump pointer
	anda	#$0F		; mask upper bits
	lda	a,u
	adda	dasamp+1	; add diff to current sample
	sta     dasamp+1	; store as new current
	asla			; upper 6 bits
	asla			; for dac store
	sta     AUDIO_PORT	; out on dac

****************************************
* just a timing delay
****************************************

delay2	ldb	#8		; adjust for sample rate
w2	decb
	bne	w2

****************************************
* Sample plays once only
****************************************

	cmpx	#sample.end
	blo	getnxt

; End of routine written by Simon Jonassen and slightly modified by me

	rts

;********************************************
; 2 voice inherent sawtooth player
; for 6 bit dac @$ff20 using HYSNC on coco2
; (C) Simon Jonassen (invisible man)
;
; FREE FOR ALL - USE AS YOU SEE FIT, JUST
; REMEMBER WHERE IT ORGINATED AND GIVE CREDIT
;********************************************
musplay		orcc		#$50		;nuke irq/firq

;********************************************
; SETUP IRQ ROUTINE
;********************************************
		lda		$ff01		ENABLE HSYNC VECTORED IRQ
		ora		#3		3/1 DEPENDS ON EDGE
		sta		$ff01
		lda		$ff00		ACK ANY OUTSTANDING HSYNC
;********************************************
; ENABLE IRQ/FIRQ
;********************************************
;		lda		#$ff
;		sta		music_on
		com		music_on+1
		andcc		#$af		;enable irq
		rts

; End of work by Simon Jonassen

******************
* Clear the screen
*
* Inputs: None
* Outputs: None
******************

GREEN_BOX       EQU     $60
WHITE_BOX       EQU     $CF

clear_screen:

	ldx	#TEXTBUF
	ldd	#GREEN_BOX << 8 | GREEN_BOX	; Two green boxes

_clear_screen_loop:
	std	,x++
	std	,x++
	std	,x++
	std	,x++

	cmpx	#TEXTBUFEND		; Finish in the lower-right corner
	bne	_clear_screen_loop
	rts

*****************************
* Clear a line
*
* Inputs:
* A = Line to clear (0 to 15)
*
* Outputs: None
*****************************

clear_line:

	ldx	#TEXTBUF
	ldb	#COLS_PER_LINE
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
* A = Line number (0 to 15)
* B = Character position (0 to 31)
* X = String to print
*
* Outputs:
* A = 0 Finished, everything is okay
* A = (Non-zero) User wants to skip
************************************************

text_appears:

	tfr	x,u		; U = string to print
	pshs	b
	ldy	#TEXTBUF
	ldb	#COLS_PER_LINE
	mul
	leax	d,y		; X is where to start the animation
	puls	b		; B is the character position to start
				;   printing the string

_text_appears_buff_box:
	lda	#WHITE_BOX	; A buff (whiteish) box
	sta	,x		; Put it on the screen

	pshs	b,x,u
	jsr	wait_for_vblank_and_check_for_skip
	puls	b,x,u
	tsta			; Has the user chosen to skip?
	beq	_text_appears_keep_going
	rts			; If yes, just return a

_text_appears_keep_going:
	pshs	b,x,u
	bsr	creature_blink	; The creature in the top-left corner
	puls	b,x,u

	tstb			; If non-zero, we are not printing out
	bne	_text_appears_green_box	; yet

	lda	,u+		; Get the next character from the string
	bne	_text_appears_store_char	; And put it on the screen

	leau	-1,u		; It was a zero we retrieved: Repoint U
				; And fall through to using a green box

_text_appears_green_box:
	tstb
	beq	_text_appears_skip_decrement

	decb

_text_appears_skip_decrement:
	lda	#GREEN_BOX	; Put a green box in A

_text_appears_store_char:
	sta	,x+	; Put the relevant character (green box or char) into
			;   the relevant position

	pshs	d
	tfr	x,d
	andb	#0b00011111	; Is the character position divisible by 32?
	puls	d
	bne	_text_appears_buff_box	; If no, then go back and do it again

	clra			; User has not chosen to skip
	rts			; Return to the main code

*****************
* Creature blinks
*
* Inputs: None
* Outputs: None
*****************

creature_blink_finished:
	RZB	1

creature_blink:

	tst	creature_blink_finished
	bne	_creature_blink_skip

	ldd	_creature_blink_frames
	addd	#1
	std	_creature_blink_frames

	lda	_creature_blink_is_blinking
	beq	_creature_blink_open_eyes

	ldd	_creature_blink_frames
	cmpd	#5
	blo	_creature_blink_take_no_action

; Open the creature's eyes

	clr	_creature_blink_is_blinking
	clra
	clrb
	std	_creature_blink_frames

	ldx	#TEXTBUF+COLS_PER_LINE+1
	lda	#'O'
	sta	,x
	sta	2,x

_creature_blink_skip:
	rts

_creature_blink_open_eyes:

	ldd	_creature_blink_frames
	cmpd	#85
	blo	_creature_blink_take_no_action

; Close the creature's eyes

	lda	#1
	sta	_creature_blink_is_blinking
	clra
	clrb
	std	_creature_blink_frames

	ldx	#TEXTBUF+COLS_PER_LINE+1
	lda	#'-' + 64
	sta	,x
	sta	2,x

_creature_blink_take_no_action:
	rts

_creature_blink_is_blinking:
	RZB	1

_creature_blink_frames:
	RZB	2

*************************************
* Encases text on the screen
* A = Line number
* B = Direction (0 = right, 1 = left)
*
* Outputs:
* A = 0 Finished, everything is okay
* A = (Non-zero) User wants to skip
*************************************

EQUALS_SIGN	EQU	125

encase_text:

	tfr	d,y		; Y (lower 8 bits) is direction

	ldb	#COLS_PER_LINE
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
	jsr	wait_for_vblank_and_check_for_skip
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

	lda	#EQUALS_SIGN	; then put a '=' in it

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
	lda	#EQUALS_SIGN		; This is '='
	sta	-COLS_PER_LINE,x	; add '=' above
	sta	+COLS_PER_LINE,x	;   and below

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

	jsr	wait_for_vblank_and_check_for_skip	; The final showing
	rts			; we are finished. Return A

_encase_right:
	tfr	d,y
	tfr	x,d
	andb	#0b00011111	; If X is evenly divisible
	tfr	y,d
	bne	_encase_text_loop	;   by 32, then

	jsr	wait_for_vblank_and_check_for_skip	; The final showing
	rts			; we are finished. Return A

**************************************
* Flashes text with white (buff) boxes
*
* Inputs:
* A = Line number (0 to 15)
* B = Number of times to flash
**************************************

flash_text_white:

	tstb
	beq	_flash_finished	; Handle the case where B = 0

	decb			; We test at the bottom
	pshs	b

	ldb	#COLS_PER_LINE
	mul
	ldx	#TEXTBUF
	leax	d,x		; X = starting position

	ldy	#flash_text_storage

_flash_copy_line:
	ldd	,x++		; Save the whole line
	std	,y++

	cmpy	#flash_text_storage_end
	bne	_flash_copy_line

				; Now the line has been saved,
				; Turn all text to white

	leax	-COLS_PER_LINE,x	; Back to the start of the line

	puls	b

_flash_chars_loop:
	pshs	b,x
	bsr	flash_chars_white
	jsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	_skip_flash_chars
	rts

_skip_flash_chars:
	pshs	b,x
	bsr	restore_chars
	jsr	wait_for_vblank_and_check_for_skip
	puls	b,x
	tsta
	beq	_skip_flash_chars_2
	rts

_skip_flash_chars_2:
	tstb			; We do this routine B times
	beq	_flash_finished

	decb
	bra	_flash_chars_loop

_flash_finished:
	clra
	rts			; Done, go away now

*********************************
* Turns all chars on a line white
*********************************

flash_chars_white:

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

restore_chars:

	ldy	#flash_text_storage

_flash_restore_chars:
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++

	cmpy	#flash_text_storage_end
	bne	_flash_restore_chars

	rts

flash_text_storage:

	RZB	COLS_PER_LINE

flash_text_storage_end:

**************************
* Flashes the screen white
*
* Inputs: None
* Outputs: None
**************************

flash_screen:

	ldx	#TEXTBUF
	ldy	#flash_screen_storage	; We overwrite the sound data

_flash_screen_copy_loop:
	ldd	,x++			; Make a copy of everything
	std	,y++			; on the screen
	ldd	,x++
	std	,y++
	ldd	,x++
	std	,y++
	ldd	,x++
	std	,y++

	cmpx	#TEXTBUFEND
	blo	_flash_screen_copy_loop

	jsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_flash_screen_no_skip

	rts

_flash_screen_no_skip:
	jsr	wait_for_vblank_and_check_for_skip
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

	jsr	wait_for_vblank_and_check_for_skip	; If space was pressed
	tsta
	beq	_skip_flash_screen_2
	rts				; return to caller

_skip_flash_screen_2:
	jsr	wait_for_vblank_and_check_for_skip	; If space was pressed
	tsta
	beq	_skip_flash_screen_3
	rts				; return to caller

_skip_flash_screen_3:
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_skip_flash_screen_4
	rts

_skip_flash_screen_4:
	ldx	#TEXTBUF
	ldy	#flash_screen_storage

_flash_screen_restore_loop:
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++

	cmpx	#TEXTBUFEND
	bne	_flash_screen_restore_loop

	jsr	wait_for_vblank_and_check_for_skip
	tsta
	beq	_flash_screen_skip_5
	rts

_flash_screen_skip_5:
	jsr	wait_for_vblank_and_check_for_skip
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

	cmpa	#TEXT_LINES		; until the starting position is off
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

	jsr	clear_line		; Clear the top line

	jsr	wait_for_vblank_and_check_for_skip
	rts

_drop_line:
	cmpa	#TEXT_LINES-1
	blo	_do_drop

	clra
	rts				; Off the bottom end of the screen


_do_drop:
	ldb	#COLS_PER_LINE
	mul
	ldx	#TEXTBUF
	leax	d,x			; X = pointer to a line of the screen

	ldb	#COLS_PER_LINE

_move_line_down:
	lda	,x			; Retrieve the character
	sta	COLS_PER_LINE,x		; and store it one line below
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
* X = Graphic data
************************

display_text_graphic:
	clra
	clrb

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
        cmpa    #TEXT_END
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

*****************
* Opening credits
*****************

opening_credits:

	jsr	clear_screen

	lda	#WAIT_PERIOD
	jsr	wait_frames		; Ignore return value

	ldx	#opening_credits_text
	bsr	roll_credits

	rts

opening_credits_text:

	FCB	7
	FCV	"CREDITS"
	FCB	0
	FCB	9
	FCV	"GO HERE"
	FCB	0
	FCB	0

	FCB	7
	FCV	"ANOTHER CREDIT"
	FCB	0
	FCB	9
	FCV	"AND ANOTHER"
	FCB	0
	FCB	0

	FCB	3
	FCV	"BLAH BLAH BLAH BLAH BLAH"
	FCB	0
	FCB	5
	FCV	"AND ANOTHER BLAH BLAH BLAH"
	FCB	0
	FCB	0
	FCB	TEXT_END

line:

	RZB	1

roll_credits:

_roll_credits_loop:

	lda	,x
	cmpa	#TEXT_END
	beq	_roll_credits_finished

	pshs	x
	jsr	clear_screen
	puls	x

_roll_credit:
	lda	,x+				; Get starting vertical line
	sta	line

	pshs	x
	bsr	roll_credits_start_pos		; Get start horizontal position in A
	puls	x

	ldb	line

	pshs	x
	bsr	credit_appears			; Send A,B,X
	puls	x
	tsta
	bne	_roll_credits_skip

_roll_credits_find_next:
	lda	,x+
	bne	_roll_credits_find_next

	lda	,x
	beq	_page_done

	bra	_roll_credit

_roll_credits_finished:
	clra
	rts

_page_done:
	lda	#WAIT_PERIOD*4
	jsr	wait_frames
	tsta
	bne	_roll_credits_skip

	leax	1,x

	bra	_roll_credits_loop

_roll_credits_skip:
	lda	#1
	rts

************************
* Roll credits start pos
*
* Input:
* X = String to print
*
* Output:
* A = Position to start
************************

roll_credits_start_pos:

	jsr	measure_line	; Line length is in A

	pshs	a
	ldb	#COLS_PER_LINE
	subb	,s		; subb a
	puls	a

	lsrb			; divide by 2
	tfr	b,a		; A = (COLS_PER_LINE - len(x)) / 2

	rts

**********************
* Credit appears
*
* A = Horizontal position
* B = Line number
* X = Credit text
**********************

credit_roll_finished:

	RZB	1

left_box:

	RZB	1

right_box:

	RZB	1

horizontal_position:

	RZB	1

line_number:

	RZB	1

string_text:

	RZB	2

string:

	RZB	COLS_PER_LINE

string_end:

credit_appears:

	clr	credit_roll_finished

	sta	horizontal_position
	stb	line_number
	stx	string_text

	lda	#15
	sta	left_box

	lda	#16
	sta	right_box

	jsr	produce_string

_credit_appears_loop:

	jsr	display_boxes
	jsr	display_chars
	jsr	display_proceed

	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	_credits_skip

	tst	credit_roll_finished
	bne	_credits_finished

	bra	_credit_appears_loop

_credits_skip:
	lda	#1
	rts

_credits_finished:
	jsr	display_string
	clra
	rts

****************
* Produce string
****************

produce_string:

	ldy	string_text
	ldx	#string

	ldb	horizontal_position

_left_boxes:
	tstb
	beq	_printing_now
	lda	#GREEN_BOX
	sta	,x+
	decb
	bra	_left_boxes

_printing_now:

	lda	,y+
	beq	_produce_string_right
	sta	,x+

	bra	_printing_now

_produce_string_right:
	lda	#GREEN_BOX

_produce_string_right_loop:
	sta	,x+
	cmpx	#string_end
	bne	_produce_string_right_loop

		; The string text is at the right location within string

	rts

******************************************
* Measure line
*
* Inputs:
* X = Pointer to a string, null-terminated
*
* Outputs:
* A = Length of that string
******************************************

measure_line:

	clra

_measure_line_loop:
	ldb	,x+
	beq	_measure_line_finished

	inca
	bra	_measure_line_loop

_measure_line_finished:
	rts			; Return A

***************
* Display boxes
*
* Inputs: None
* Outputs: None
***************

display_boxes:

	ldx	#TEXTBUF
	lda	line_number
	ldb	#COLS_PER_LINE
	mul
	leax	d,x

	lda	left_box

	ldb	#WHITE_BOX
	stb	a,x

	lda	right_box
	stb	a,x

	rts

***************
* Display chars
*
* Inputs: None
* Outputs: None
***************

display_chars:

	ldx	#TEXTBUF
	lda	line_number
	ldb	#COLS_PER_LINE
	mul
	leax	d,x			; X = start of the line

	ldy	#string

	lda	left_box		; A = left box
	ldb	right_box
	pshs	b			; ,S = right box

_display_chars_loop:
	inca
	cmpa	,s
	bhs	_display_characters_finished

	ldb	a,y
	stb	a,x

	bra	_display_chars_loop

_display_characters_finished:
	puls	b
	rts

*****************
* Display proceed
*
* Inputs: None
* Outputs: None
*****************

display_proceed:

	lda	left_box
	beq	_display_proceed_finished

	dec	left_box
	inc	right_box

	clra
	rts

_display_proceed_finished:
	lda	#1
	sta	credit_roll_finished
	rts

****************
* Display string
****************

display_string:

        ldx     #TEXTBUF
        lda     line_number
        ldb     #COLS_PER_LINE
        mul
        leax    d,x                     ; X = start of the line

        ldy     #string
	clra

_display_string_loop:
        ldb     a,y
        stb     a,x

	inca
	cmpa	#32
	beq	_display_string_finished
        bra     _display_string_loop

_display_string_finished:
        rts

****************
* Loading screen
****************

loading_screen:

	jsr	clear_screen

	lda	#WAIT_PERIOD
	jsr	wait_frames

	clra
	clrb
	ldx	#ascii_art_cat
	jsr	display_text_graphic

	ldx	#loading_text
	lda	#15
	ldb	#11
	jsr	text_appears		; Ignore the return value
	tsta
	bne	_skipped_loading_screen

	jsr	wait_for_vblank_and_check_for_skip
					; Display it for one frame
	tsta
	bne	_skipped_loading_screen

	lda	#15
	ldb	#3
	jsr	flash_text_white	; Ignore the return value

	rts

_skipped_loading_screen:

	jsr	clear_screen
	rts

; This graphic was made by Microsoft Copilot and modified by me
; Animation done by me

title_screen_graphic:
	FCV	"(\\/)",0
	FCV	"(O-O)",0
	FCV	"/> >\\",0
	FCB	TEXT_END

title_screen_text:
	FCB	5, 5
	FCN	"RJFC"	; Each string ends with a zero when you use FCN
	FCB	8, 9
	FCN	"PRESENTS"
	FCB	12, 11
	FCV	"TEXT MODE MEGADEMO" ; FCV places green boxes for spaces
	FCB	0		; So we manually terminate that line
	FCB	TEXT_END	; The end

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
	FCV	"        :  '  !    ;       ;-.",0
	FCV	"        ; '   : :'-:     ..'* ;",0
	FCV	"[BUG].*' /  .*' ; .*'- +'  '*'",0
	FCV	"     '*-*   '*-*  '*-*'",0
	FCB	TEXT_END

ascii_art_cat_end:

loading_text:

	FCV	"LOADING...",0

************************************
* Here is our raw data for our sound
************************************

flash_screen_storage:		; Use the area of memory reserved for
				; the sound, because we're not
				; using it again

            fcb     $f8,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $f9,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $fa,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $fb,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $fc,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $fd,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $fe,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
table1:
            fcb     $00,$01,$02,$03,$04,$05,$06,$07,$f8,$f9,$fa,$fb,$fc,$fd,$fe,$ff
            fcb     $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $03,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $04,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $05,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $06,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
            fcb     $07,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

sample:     fcb     32
            fcb     $0f,$10,$00,$f0,$10,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$0f,$10
            fcb     $00,$f0,$01,$f1,$f0,$10,$00,$f0
            fcb     $00,$00,$1f,$01,$f1,$f1,$f0,$00
            fcb     $1f,$10,$0f,$10,$00,$00,$0f,$1f
            fcb     $01,$00,$00,$0f,$10,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$10,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $00,$00,$00,$00,$0f,$00,$10,$00
            fcb     $00,$00,$00,$10,$00,$00,$00,$01
            fcb     $00,$00,$00,$10,$f0,$00,$10,$00
            fcb     $00,$0f,$0f,$1f,$10,$dd,$de,$01
            fcb     $10,$0f,$f7,$76,$39,$98,$d3,$67
            fcb     $12,$0d,$c0,$12,$fc,$de,$25,$43
            fcb     $dd,$ce,$23,$43,$0e,$d0,$11,$0f
            fcb     $ff,$01,$1f,$ff,$ef,$ef,$00,$10
            fcb     $0d,$0f,$fe,$71,$71,$56,$8e,$88
            fcb     $d7,$67,$2f,$cb,$b4,$33,$0b,$ce
            fcb     $45,$52,$cd,$d0,$33,$21,$fd,$01
            fcb     $01,$ff,$e0,$00,$1f,$fe,$df,$f2
            fcb     $21,$cc,$b0,$46,$63,$3c,$fb,$c2
            fcb     $04,$22,$ef,$ff,$21,$ff,$ee,$04
            fcb     $43,$1e,$df,$11,$21,$01,$ff,$ff
            fcb     $f0,$0f,$00,$0f,$fd,$e0,$12,$ec
            fcb     $df,$24,$32,$30,$ff,$d0,$11,$11
            fcb     $0f,$00,$11,$1f,$ee,$02,$31,$10
            fcb     $02,$10,$ee,$f1,$31,$0e,$ef,$e0
            fcb     $ff,$f0,$f0,$1f,$ec,$df,$12,$46
            fcb     $42,$fc,$dd,$01,$32,$00,$f1,$01
            fcb     $0f,$0e,$02,$33,$11,$ef,$e0,$10
            fcb     $10,$00,$ff,$ff,$ff,$ff,$0f,$1f
            fcb     $ed,$ef,$00,$36,$34,$fd,$dd,$02
            fcb     $31,$1f,$d1,$12,$20,$ee,$02,$33
            fcb     $11,$de,$e0,$12,$1f,$ff,$f0,$0f
            fcb     $ed,$f0,$11,$fd,$ce,$f2,$47,$51
            fcb     $eb,$ce,$13,$42,$ff,$e0,$22,$10
            fcb     $ee,$02,$44,$1f,$dd,$e1,$12,$1f
            fcb     $ef,$ff,$fe,$f0,$01,$ee,$de,$f0
            fcb     $57,$52,$da,$cf,$24,$30,$fe,$e2
            fcb     $33,$1e,$de,$14,$52,$fe,$ce,$02
            fcb     $21,$0e,$ee,$e0,$f0,$ff,$ee,$ef
            fcb     $03,$74,$3e,$bd,$d2,$33,$10,$ee
            fcb     $11,$22,$0f,$f0,$23,$10,$0d,$f0
            fcb     $11,$0f,$ee,$e0,$0f,$fe,$ee,$e0
            fcb     $46,$42,$eb,$df,$13,$30,$0f,$e1
            fcb     $22,$20,$ee,$11,$42,$0e,$ef,$01
            fcb     $00,$ee,$ff,$0f,$de,$de,$15,$64
            fcb     $2c,$cc,$f3,$33,$1e,$ee,$22,$41
            fcb     $fd,$e0,$34,$20,$ed,$f0,$01,$0f
            fcb     $ee,$ff,$ef,$de,$15,$54,$0d,$cd
            fcb     $03,$32,$0f,$ef,$23,$40,$de,$e2
            fcb     $32,$1f,$fe,$0f,$00,$ff,$ff,$ef
            fcb     $dd,$e3,$45,$4f,$dd,$e1,$23,$10
            fcb     $ef,$02,$33,$0e,$ef,$11,$12,$0f
            fcb     $fe,$f0,$00,$fe,$de,$ef,$f3,$43
            fcb     $3e,$ee,$f1,$11,$11,$0f,$11,$32
            fcb     $ef,$f0,$12,$01,$ff,$fe,$00,$ff
            fcb     $ee,$fe,$fe,$34,$43,$ed,$df,$12
            fcb     $21,$0e,$01,$24,$10,$ee,$01,$21
            fcb     $1f,$ed,$f0,$00,$fe,$ee,$ef,$f6
            fcb     $43,$1c,$de,$02,$31,$ff,$f1,$33
            fcb     $31,$ed,$d1,$23,$20,$dc,$e0,$10
            fcb     $fd,$de,$ff,$36,$32,$eb,$fe,$32
            fcb     $20,$ef,$f3,$43,$2f,$dd,$02,$33
            fcb     $fe,$be,$02,$1e,$cc,$df,$12,$73
            fcb     $2e,$bf,$f2,$21,$0f,$f0,$24,$41
            fcb     $fd,$d0,$23,$10,$ed,$e0,$10,$dc
            fcb     $ce,$11,$54,$20,$de,$00,$21,$0f
            fcb     $00,$23,$13,$ff,$ef,$21,$00,$ff
            fcb     $f1,$fe,$cd,$df,$f2,$64,$2f,$b0
            fcb     $f2,$20,$ff,$02,$42,$1f,$0f,$01
            fcb     $0f,$f0,$10,$0f,$dd,$de,$ee,$e6
            fcb     $64,$1b,$ef,$22,$0f,$e1,$15,$20
            fcb     $0f,$00,$10,$ff,$01,$0f,$ff,$dd
            fcb     $dd,$ff,$56,$31,$dd,$11,$10,$ef
            fcb     $12,$32,$01,$10,$fe,$3e,$f0,$01
            fcb     $ff,$ee,$de,$dd,$f5,$74,$1c,$e1
            fcb     $11,$de,$f2,$33,$20,$10,$3f,$ee
            fcb     $00,$11,$ee,$f0,$0e,$cc,$ee,$27
            fcb     $14,$1e,$f2,$2f,$ce,$f2,$30,$21
            fcb     $23,$2f,$cf,$01,$01,$fe,$f0,$fe
            fcb     $dd,$ee,$f2,$71,$30,$0f,$21,$ec
            fcb     $ff,$32,$f2,$14,$4f,$fd,$11,$0e
            fcb     $00,$ff,$ee,$ff,$de,$ef,$06,$30
            fcb     $21,$20,$fd,$0f,$1f,$02,$23,$11
            fcb     $10,$00,$ef,$00,$ef,$ef,$ef,$ef
            fcb     $ff,$02,$50,$2f,$31,$0f,$e1,$f1
            fcb     $e1,$11,$10,$11,$00,$0f,$f0,$0f
            fcb     $0f,$0f,$0f,$f0,$1f,$0f,$10,$0f
            fcb     $f1,$00,$01,$02,$01,$00,$10,$10
            fcb     $10,$10,$00,$00,$f0,$f0,$ff,$f0
            fcb     $f0,$f0,$0f,$0f,$00,$00,$01,$01
            fcb     $01,$11,$10,$11,$01,$00,$00,$00
            fcb     $f0,$ff,$0f,$f0,$0f,$0f,$00,$f0
            fcb     $00,$00,$00,$01,$01,$01,$01,$10
            fcb     $10,$00,$10,$00,$0f,$00,$0f,$00
            fcb     $f0,$00,$f0,$0f,$00,$f0,$00,$f1
            fcb     $00,$00,$10,$01,$00,$01,$01,$00
            fcb     $01,$00,$00,$00,$00,$0f,$00,$f0
            fcb     $00,$f0,$0f,$00,$0f,$00,$00,$00
            fcb     $00,$01,$00,$01,$00,$10,$00,$10
            fcb     $01,$00,$00,$00,$00,$f0,$00,$f0
            fcb     $00,$f0,$00,$f0,$00,$0f,$00,$00
            fcb     $01,$00,$00,$10,$10,$00,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$00,$f0
            fcb     $00,$f0,$00,$00,$f0,$00,$00,$00
            fcb     $10,$00,$00,$00,$00,$00,$01,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$0f,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$0f,$00,$00,$00,$00
            fcb     $1f,$00,$00,$01,$f1,$f1,$f1,$f1
            fcb     $f1,$e3,$fe,$2e,$2f,$10,$f0,$01
            fcb     $f1,$0f,$10,$f1,$00,$00,$00,$00
            fcb     $00,$f1,$f1,$f1,$f1,$1f,$10,$ff
            fcb     $00,$0f,$2e,$1f,$20,$f1,$0f,$10
            fcb     $f1,$f2,$e0,$1f,$00,$00,$00,$1e
            fcb     $3d,$3e,$10,$f1,$f1,$e2,$f0,$10
            fcb     $f0,$1f,$1f,$10,$0f,$1f,$01,$f1
            fcb     $0f,$00,$1f,$1f,$10,$f1,$f1,$f1
            fcb     $f1,$f1,$f1,$f0,$1f,$1f,$01,$1d
            fcb     $3e,$01,$f0,$1f,$02,$d2,$f1,$f1
            fcb     $0f,$1f,$01,$f1,$0f,$1f,$1f,$00
            fcb     $00,$10,$d4,$ef,$3d,$2f,$01,$0f
            fcb     $02,$d3,$e1,$0f,$01,$f1,$0e,$3e
            fcb     $1f,$1f,$2d,$3f,$f1,$00,$f2,$d4
            fcb     $c2,$00,$e3,$e0,$2e,$10,$0f,$2d
            fcb     $3f,$e2,$0e,$12,$d2,$ff,$3d,$12
            fcb     $d1,$2f,$e4,$df,$4b,$23,$b4,$fe
            fcb     $20,$ff,$59,$7b,$05,$b1,$2f,$d6
            fcb     $a4,$e2,$e0,$1e,$3d,$3d,$3d,$11
            fcb     $f0,$01,$e4,$a5,$e0,$00,$2c,$5b
            fcb     $4d,$20,$0f,$f3,$e0,$f4,$c2,$f2
            fcb     $e0,$2d,$3e,$2e,$1f,$2d,$12,$e0
            fcb     $03,$c1,$10,$ff,$4c,$2f,$02,$d1
            fcb     $1f,$1f,$00,$00,$1f,$10,$f1,$0f
            fcb     $11,$d4,$ee,$3e,$1f,$1e,$2f,$01
            fcb     $e1,$00,$f1,$00,$f1,$1f,$00,$1f
            fcb     $11,$f0,$11,$e2,$0f,$01,$f1,$ff
            fcb     $1f,$e1,$0e,$0f,$ff,$e1,$1e,$03
            fcb     $10,$22,$12,$02,$2f,$11,$ff,$ff
            fcb     $0e,$0f,$ff,$1e,$e2,$ee,$ff,$f1
            fcb     $1d,$41,$02,$21,$12,$01,$1f,$01
            fcb     $e0,$0f,$01,$f0,$3f,$d3,$0d,$ff
            fcb     $fe,$c1,$e0,$f0,$21,$21,$40,$22
            fcb     $00,$10,$e0,$f0,$e1,$1f,$01,$2f
            fcb     $00,$2e,$d0,$0b,$ee,$0d,$4f,$f4
            fcb     $32,$03,$32,$ee,$20,$ce,$10,$ff
            fcb     $13,$0f,$33,$ee,$11,$ed,$de,$ee
            fcb     $ef,$5e,$f5,$40,$04,$21,$d1,$0f
            fcb     $df,$00,$f1,$21,$01,$21,$1f,$00
            fcb     $eb,$ef,$cd,$0e,$5e,$05,$32,$13
            fcb     $30,$ef,$0e,$dd,$10,$01,$23,$10
            fcb     $22,$0e,$ff,$ed,$de,$de,$d3,$5c
            fcb     $27,$3f,$32,$0f,$ee,$fe,$ed,$33
            fcb     $f3,$41,$01,$1f,$fe,$ff,$dd,$fe
            fcb     $d1,$f3,$2d,$53,$10,$21,$ff,$ef
            fcb     $e0,$f0,$22,$30,$22,$f0,$0f,$ff
            fcb     $ff,$ef,$ee,$e0,$d3,$4c,$35,$1f
            fcb     $21,$0f,$ef,$ff,$f0,$23,$f5,$2d
            fcb     $10,$0e,$0f,$00,$df,$0f,$df,$f1
            fcb     $3c,$15,$10,$12,$10,$d0,$0e,$ff
            fcb     $32,$10,$6f,$b3,$1f,$c1,$1e,$ef
            fcb     $fe,$ee,$e4,$4b,$36,$2c,$32,$0d
            fcb     $e0,$fe,$f1,$32,$04,$2f,$f0,$0e
            fcb     $e0,$1e,$e0,$fe,$df,$e7,$10,$a7
            fcb     $6d,$e4,$1f,$cf,$3c,$d2,$30,$22
            fcb     $31,$e0,$0e,$f0,$ff,$ff,$ff,$ef
            fcb     $d2,$71,$af,$71,$2c,$13,$0e,$d1
            fcb     $0d,$f2,$21,$22,$20,$f0,$0e,$ff
            fcb     $0e,$ff,$ff,$ef,$e7,$1a,$66,$de
            fcb     $41,$ed,$01,$de,$20,$21,$32,$01
            fcb     $f0,$e1,$ef,$ff,$fe,$0d,$fe,$44
            fcb     $b2,$7f,$e3,$2e,$e0,$1d,$e1,$1f
            fcb     $24,$01,$11,$ff,$0f,$ef,$0e,$ff
            fcb     $ef,$d2,$6b,$07,$11,$c3,$3e,$f0
            fcb     $1d,$d2,$0f,$14,$10,$12,$ff,$00
            fcb     $ef,$0e,$ef,$fd,$ff,$7e,$c7,$13
            fcb     $c1,$6e,$e0,$1e,$ef,$3c,$31,$30
            fcb     $f4,$ff,$f2,$ee,$0f,$ee,$0d,$ef
            fcb     $42,$b5,$5e,$f5,$1d,$02,$fd,$f1
            fcb     $0e,$23,$f1,$21,$f0,$1f,$e0,$0d
            fcb     $e0,$ed,$ff,$6d,$e7,$12,$d2,$5d
            fcb     $f2,$0e,$d1,$0f,$f3,$2e,$23,$0e
            fcb     $11,$ef,$1e,$d0,$fd,$ee,$24,$b2
            fcb     $71,$ee,$62,$d0,$10,$de,$10,$d1
            fcb     $4f,$04,$00,$01,$0e,$00,$ee,$fe
            fcb     $ee,$e1,$5b,$17,$10,$d6,$2d,$11
            fcb     $fd,$e1,$0d,$13,$0f,$41,$00,$2f
            fcb     $f0,$fe,$ef,$ee,$df,$f6,$df,$72
            fcb     $0e,$44,$d0,$1f,$ee,$0f,$e0,$30
            fcb     $03,$20,$11,$1e,$f0,$ee,$fe,$ed
            fcb     $fd,$26,$a3,$71,$ef,$61,$e1,$0f
            fcb     $de,$1f,$d2,$11,$03,$30,$02,$0e
            fcb     $0f,$fd,$fe,$de,$fd,$17,$c0,$71
            fcb     $1d,$53,$d0,$1f,$de,$0f,$e0,$22
            fcb     $02,$32,$f1,$2e,$e1,$fc,$ff,$ed
            fcb     $ff,$c3,$71,$a0,$74,$0b,$63,$cf
            fcb     $1f,$ce,$00,$e0,$42,$f4,$31,$f1
            fcb     $2d,$e0,$fd,$ff,$fe,$fe,$fd,$47
            fcb     $18,$27,$3f,$a7,$2b,$f1,$0d,$d0
            fcb     $2d,$13,$4f,$15,$0f,$03,$ce,$0f
            fcb     $ef,$f0,$ef,$0d,$ff,$54,$96,$7c
            fcb     $e7,$ec,$1f,$fd,$f1,$0f,$23,$11
            fcb     $31,$1e,$1f,$fe,$0f,$f0,$0f,$0f
            fcb     $ff,$cf,$f7,$1d,$c7,$24,$a2,$6c
            fcb     $ff,$0f,$ee,$20,$f1,$5f,$13,$00
            fcb     $00,$ff,$e0,$0f,$11,$f0,$ff,$ed
            fcb     $dd,$37,$18,$07,$50,$a6,$3d,$d0
            fcb     $1d,$d0,$2f,$02,$31,$21,$01,$0d
            fcb     $f0,$ef,$12,$01,$01,$ee,$fe,$bc
            fcb     $e3,$72,$af,$76,$39,$25,$eb,$d1
            fcb     $0b,$e4,$2f,$23,$41,$e1,$1e,$c0
            fcb     $1e,$02,$21,$01,$2f,$ee,$dd,$db
            fcb     $cf,$73,$3a,$72,$73,$dd,$4f,$da
            fcb     $d1,$ed,$24,$22,$23,$10,$ef,$fe
            fcb     $ef,$11,$12,$40,$10,$0f,$ee,$fe
            fcb     $dd,$ee,$c0,$57,$12,$f6,$4c,$c0
            fcb     $fd,$cf,$11,$03,$42,$00,$10,$ee
            fcb     $f1,$ff,$22,$02,$20,$00,$f0,$fe
            fcb     $ff,$0e,$f0,$ed,$ef,$35,$e0,$61
            fcb     $d0,$1f,$fe,$f1,$10,$12,$2f,$f1
            fcb     $1f,$f1,$1f,$01,$10,$10,$01,$0f
            fcb     $1f,$f0,$0e,$f2,$ed,$fd,$ee,$f2
            fcb     $40,$24,$0f,$00,$ff,$ff,$20,$01
            fcb     $21,$f0,$11,$f1,$00,$11,$f0,$10
            fcb     $00,$10,$00,$f0,$fe,$0f,$0f,$f0
            fcb     $ff,$fc,$f0,$21,$f2,$41,$e0,$10
            fcb     $f0,$f2,$00,$02,$1f,$01,$10,$10
            fcb     $10,$00,$00,$00,$00,$00,$0f,$00
            fcb     $fe,$00,$fe,$10,$ef,$0e,$0f,$f1
            fcb     $3f,$03,$ff,$11,$00,$01,$10,$10
            fcb     $01,$00,$11,$00,$10,$00,$00,$00
            fcb     $00,$0f,$00,$f0,$0f,$0f,$00,$ff
            fcb     $00,$ff,$f0,$ff,$02,$f0,$01,$00
            fcb     $01,$11,$00,$11,$00,$01,$01,$00
            fcb     $10,$00,$00,$00,$00,$00,$f0,$00
            fcb     $f0,$0f,$00,$0f,$00,$f0,$00,$00
            fcb     $00,$f0,$00,$00,$00,$1f,$10,$00
            fcb     $01,$01,$0f,$01,$00,$01,$f1,$00
            fcb     $00,$00,$00,$0f,$00,$00,$00,$00
            fcb     $0f,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$10
            fcb     $00,$00,$00,$00,$00,$f1,$00,$00
            fcb     $f1,$f0,$1f,$00,$00,$00,$1f,$00
            fcb     $00,$00,$00,$00,$00,$00,$01,$f0
            fcb     $00,$10,$0f,$10,$f1,$00,$f0,$10
            fcb     $00,$00,$0f,$00,$00,$00,$01,$f0
            fcb     $00,$1f,$00,$1f,$1f,$1f,$10,$f1
            fcb     $00,$00,$f1,$00,$0f,$10,$00,$00
            fcb     $00,$00,$00,$00,$f1,$0f,$10,$00
            fcb     $f1,$0f,$10,$00,$1f,$00,$00,$00
            fcb     $00,$f1,$f0,$10,$00,$f1,$00,$f0
            fcb     $1f,$00,$10,$0f,$01,$00,$f1,$0f
            fcb     $10,$f1,$0f,$01,$00,$00,$f1,$00
            fcb     $f0,$00,$00,$1f,$10,$0f,$10,$0f
            fcb     $10,$f1,$f0,$10,$f1,$f1,$0f,$1f
            fcb     $00,$00,$1f,$00,$01,$f0,$00,$00
            fcb     $1f,$00,$00,$00,$00,$01,$f0,$00
            fcb     $1f,$00,$1f,$00,$01,$f0,$00,$00
            fcb     $00,$01,$f0,$01,$0e,$2f,$1f,$01
            fcb     $0f,$10,$f1,$f0,$10,$f1,$0f,$01
            fcb     $f1,$0f,$10,$00,$0f,$1f,$01,$f0
            fcb     $10,$f1,$0f,$1f,$01,$0f,$00,$10
            fcb     $f0,$10,$f0,$10,$f1,$00,$f1,$00
            fcb     $f0,$1f,$1f,$10,$00,$f1,$00,$00
            fcb     $f1,$f1,$00,$0f,$01,$00,$0f,$10
            fcb     $0f,$1f,$10,$00,$f1,$f1,$f1,$00
            fcb     $0f,$10,$0f,$1f,$10,$00,$00,$f1
            fcb     $00,$00,$f1,$f1,$00,$00,$0f,$1f
            fcb     $1f,$10,$0f,$1f,$10,$f1,$00,$00
            fcb     $00,$00,$00,$0f,$00,$10,$00,$00
            fcb     $f1,$f1,$f1,$f0,$00,$1f,$1f,$00
            fcb     $01,$f1,$f0,$00,$00,$00,$00,$1f
            fcb     $00,$00,$01,$f0,$1f,$01,$f1,$f0
            fcb     $00,$00,$01,$0f,$10,$0f,$1f,$00
            fcb     $01,$00,$f0,$00,$00,$01,$f0,$10
            fcb     $0f,$00,$1f,$01,$f0,$00,$01,$f1
            fcb     $f0,$00,$01,$f0,$01,$f1,$f0,$1f
            fcb     $00,$1f,$00,$1f,$00,$01,$f0,$1f
            fcb     $01,$f1,$f0,$1f,$00,$00,$10,$f1
            fcb     $f1,$f0,$01,$f0,$1f,$1f,$1f,$1f
            fcb     $1f,$1f,$00,$10,$f1,$00,$f1,$f1
            fcb     $0f,$10,$00,$f1,$0f,$10,$00,$00
            fcb     $0f,$10,$00,$00,$00,$00,$00,$f1
            fcb     $f1,$00,$00,$0f,$10,$f0,$10,$00
            fcb     $f1,$f1,$f1,$f1,$0f,$10,$f1,$0f
            fcb     $1f,$1f,$00,$1f,$00,$01,$f1,$f1
            fcb     $f1,$f0,$01,$0f,$00,$1f,$00,$1f
            fcb     $1f,$1f,$01,$f1,$f0,$01,$f1,$f1
            fcb     $f1,$f1,$f0,$1f,$1f,$1f,$1f,$00
            fcb     $1f,$01,$f1,$f1,$f1,$f0,$00,$10
            fcb     $f1,$0f,$01,$f1,$f0,$1f,$00,$1f
            fcb     $1f,$1f,$00,$10,$f0,$01,$f0,$10
            fcb     $f1,$f1,$f0,$01,$0f,$1f,$1f,$00
            fcb     $1f,$01,$f1,$f1,$0f,$01,$00,$0f
            fcb     $10,$f0,$1f,$01,$00,$f1,$f1,$f1
            fcb     $0f,$1f,$1f,$1f,$10,$00,$00,$f1
            fcb     $f1,$f1,$00,$f1,$00,$00,$00,$f1
            fcb     $0f,$1f,$1f,$1f,$10,$00,$f1,$0f
            fcb     $01,$0f,$1f,$10,$f1,$f1,$f1,$f0
            fcb     $01,$f0,$1f,$1f,$1f,$1f,$1f,$00
            fcb     $01,$f1,$f1,$f1,$f1,$f1,$f0,$00
            fcb     $1f,$1f,$1f,$10,$00,$00,$f1,$f1
            fcb     $f1,$f1,$f1,$00,$00,$00,$0f,$10
            fcb     $0f,$10,$00,$f1,$f0,$01,$0f,$00
            fcb     $00,$00,$0f,$00,$00,$f1,$00,$f0
            fcb     $00,$00,$10,$10,$10,$10,$10,$10
            fcb     $01,$00,$0f,$00,$0f,$00,$0f,$00
            fcb     $f0,$f0,$0f,$f0,$f0,$ff,$f1,$1d
            fcb     $21,$00,$21,$11,$02,$00,$01,$e0
            fcb     $0f,$f0,$0f,$00,$00,$10,$00,$21
            fcb     $01,$11,$01,$00,$f0,$0f,$f0,$ff
            fcb     $f0,$ff,$00,$ff,$0f,$f0,$ff,$01
            fcb     $1e,$32,$f1,$30,$02,$10,$f1,$0f
            fcb     $e1,$0e,$f1,$ff,$01,$f0,$10,$01
            fcb     $10,$11,$11,$01,$00,$00,$0f,$0f
            fcb     $0f,$0f,$f0,$0f,$0f,$0f,$0f,$0f
            fcb     $0e,$0f,$2f,$e6,$e0,$23,$f1,$30
            fcb     $00,$1f,$f0,$0e,$f1,$fe,$01,$e0
            fcb     $10,$f1,$10,$02,$1f,$12,$00,$10
            fcb     $f1,$00,$00,$f0,$0f,$0f,$0f,$00
            fcb     $f0,$0f,$0f,$0f,$0f,$ff,$02,$c3
            fcb     $2d,$23,$0f,$40,$01,$11,$e1,$0f
            fcb     $e2,$ef,$00,$ff,$1f,$00,$1f,$01
            fcb     $1f,$21,$f1,$10,$02,$f0,$10,$f0
            fcb     $10,$f0,$0f,$00,$ff,$00,$f0,$0f
            fcb     $00,$ff,$0f,$0e,$11,$c4,$0e,$22
            fcb     $00,$30,$10,$20,$f2,$ff,$01,$ef
            fcb     $00,$e0,$0f,$00,$0f,$10,$01,$10
            fcb     $01,$10,$02,$f0,$11,$f1,$00,$00
            fcb     $0f,$00,$ff,$00,$f0,$0f,$00,$f0
            fcb     $0f,$0f,$f0,$f0,$0f,$11,$f1,$2f
            fcb     $12,$10,$11,$00,$10,$f0,$00,$f0
            fcb     $ff,$00,$f0,$0f,$00,$00,$10,$01
            fcb     $01,$00,$10,$10,$10,$01,$00,$00
            fcb     $0f,$00,$0f,$00,$f0,$f0,$f0,$0f
            fcb     $0f,$0f,$0f,$f0,$00,$f2,$f0,$21
            fcb     $01,$20,$11,$1f,$10,$0f,$1f,$f0
            fcb     $0f,$f0,$f0,$0f,$00,$00,$01,$00
            fcb     $10,$01,$01,$01,$00,$10,$00,$10
            fcb     $00,$f0,$00,$f0,$f0,$0f,$00,$f0
            fcb     $f0,$f0,$0f,$0f,$f0,$00,$00,$11
            fcb     $01,$10,$12,$01,$10,$00,$00,$f0
            fcb     $0f,$f0,$f0,$f0,$f0,$00,$00,$00
            fcb     $10,$10,$01,$01,$01,$00,$10,$00
            fcb     $00,$00,$0f,$00,$f0,$0f,$00,$0f
            fcb     $00,$0f,$00,$0f,$00,$f0,$0f,$00
            fcb     $10,$01,$01,$01,$10,$10,$10,$00
            fcb     $0f,$00,$0f,$00,$0f,$00,$00,$00
            fcb     $00,$00,$00,$00,$10,$00,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$00,$0f
            fcb     $00,$00,$0f,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$00,$00
            fcb     $00,$00,$10,$00,$00,$10,$00,$00
            fcb     $10,$00,$00,$f0,$00,$00,$00,$00
            fcb     $f0,$00,$00,$00,$00,$00,$01,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $10,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$0f,$00,$00,$01,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$0f,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $01,$f1,$00,$00,$00,$00,$00,$00
            fcb     $00,$0f,$00,$00,$00,$00,$01,$00
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $10,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$f0
            fcb     $00,$00,$00,$00,$00,$01,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f0,$00,$00,$00,$01,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$0f,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $10,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$0f,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$f0,$00
            fcb     $00,$00,$00,$1f,$10,$00,$22,$ef
            fcb     $01,$1f,$0f,$f0,$11,$00,$ff,$10
            fcb     $10,$00,$f0,$01,$00,$0f,$00,$01
            fcb     $0f,$00,$00,$00,$00,$f0,$00,$00
            fcb     $00,$00,$00,$00,$0f,$00,$10,$00
            fcb     $0f,$01,$00,$00,$00,$00,$00,$00
            fcb     $10,$00,$10,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$00,$00
            fcb     $f0,$00,$f0,$00,$f0,$00,$f0,$00
            fcb     $f0,$f0,$11,$11,$00,$10,$11,$f0
            fcb     $f0,$00,$00,$f0,$01,$01,$00,$01
            fcb     $11,$10,$01,$00,$00,$0f,$00,$0f
            fcb     $0f,$0f,$00,$ff,$0f,$f0,$ff,$f0
            fcb     $ff,$ff,$00,$03,$32,$01,$21,$10
            fcb     $0f,$ef,$00,$fe,$00,$01,$11,$01
            fcb     $11,$10,$f0,$00,$00,$f0,$11,$10
            fcb     $01,$00,$00,$f0,$f0,$ff,$f0,$f0
            fcb     $ff,$0f,$0f,$0f,$0f,$ff,$f0,$13
            fcb     $21,$03,$22,$00,$0f,$0f,$ee,$e0
            fcb     $00,$f0,$12,$12,$10,$01,$10,$ff
            fcb     $00,$0f,$00,$02,$10,$01,$01,$00
            fcb     $ff,$0f,$0e,$f0,$0f,$ff,$00,$00
            fcb     $ff,$f0,$ff,$ef,$24,$f0,$13,$40
            fcb     $01,$11,$ff,$ee,$00,$ee,$f1,$20
            fcb     $f1,$22,$10,$01,$10,$ff,$00,$0f
            fcb     $01,$10,$01,$10,$00,$f1,$ff,$ff
            fcb     $00,$ff,$f0,$00,$f0,$00,$ff,$ff
            fcb     $fe,$f1,$30,$f2,$33,$00,$21,$10
            fcb     $e0,$f0,$ee,$f0,$00,$f1,$11,$10
            fcb     $12,$10,$f0,$10,$00,$01,$f0,$00
            fcb     $00,$00,$00,$00,$0f,$00,$f0,$f0
            fcb     $f0,$0f,$00,$f0,$0f,$f0,$fe,$0f
            fcb     $3f,$f2,$12,$10,$12,$2f,$01,$00
            fcb     $fe,$00,$ff,$00,$00,$00,$01,$01
            fcb     $01,$11,$01,$10,$f0,$00,$f0,$f0
            fcb     $0f,$00,$00,$00,$00,$0f,$1f,$0f
            fcb     $00,$f1,$f1,$f0,$f0,$0f,$0e,$00
            fcb     $10,$f1,$11,$01,$02,$10,$00,$10
            fcb     $0f,$00,$f0,$0f,$1f,$00,$00,$00
            fcb     $00,$01,$00,$10,$10,$00,$00,$00
            fcb     $00,$0f,$1f,$00,$00,$f1,$f0,$00
            fcb     $0f,$00,$00,$f1,$0f,$00,$00,$00
            fcb     $f0,$ff,$10,$00,$01,$01,$00,$20
            fcb     $00,$10,$00,$f0,$00,$00,$00,$00
            fcb     $00,$0f,$00,$00,$00,$01,$00,$01
            fcb     $00,$00,$1f,$1f,$00,$00,$00,$f0
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$f0,$00
            fcb     $00,$01,$00,$00,$10,$00,$10,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$01,$00,$00,$00,$00
            fcb     $00,$0f,$00,$00,$00,$00,$f1,$00
            fcb     $0f,$1f,$1f,$00,$00,$00,$f0,$00
            fcb     $00,$00,$00,$00,$00,$01,$00,$00
            fcb     $00,$00,$00,$00,$00,$01,$f1,$00
            fcb     $00,$00,$00,$00,$00,$01,$f1,$00
            fcb     $00,$00,$00,$00,$00,$f0,$00,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $00,$f1,$f0,$00,$00,$00,$1f,$10
            fcb     $00,$00,$00,$00,$01,$00,$00,$00
            fcb     $00,$00,$00,$00,$10,$00,$0f,$1f
            fcb     $00,$00,$00,$00,$00,$00,$f0,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $01,$f1,$f1,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$0f,$01,$f0,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$01,$f0,$00
            fcb     $00,$00,$10,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$f1,$f1
            fcb     $00,$0f,$1f,$1f,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$f1,$00,$00,$00,$00,$00
            fcb     $00,$f1,$f1,$0f,$10,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$f0,$01
            fcb     $f0,$0f,$00,$00,$00,$10,$01,$01
            fcb     $00,$00,$00,$00,$0f,$00,$1f,$00
            fcb     $00,$00,$0f,$00,$0f,$1f,$f0,$10
            fcb     $00,$00,$1f,$00,$01,$00,$00,$10
            fcb     $f0,$01,$f0,$01,$00,$00,$00,$00
            fcb     $10,$00,$01,$00,$00,$00,$0f,$10
            fcb     $f0,$0f,$0f,$00,$0f,$0f,$00,$ff
            fcb     $0f,$f0,$31,$01,$11,$10,$f1,$1f
            fcb     $e0,$0f,$0f,$01,$1f,$10,$11,$0f
            fcb     $01,$f1,$00,$10,$01,$20,$f0,$1f
            fcb     $0f,$00,$ff,$f0,$f0,$ff,$f0,$ff
            fcb     $f0,$ef,$03,$3f,$13,$30,$0f,$11
            fcb     $de,$0f,$f0,$f1,$11,$02,$11,$10
            fcb     $f0,$0e,$0f,$00,$11,$12,$21,$01
            fcb     $f0,$fe,$f0,$ff,$ff,$00,$ff,$00
            fcb     $fd,$00,$ee,$f1,$45,$f1,$43,$0f
            fcb     $d0,$1d,$cf,$10,$00,$23,$20,$10
            fcb     $1e,$ee,$00,$ff,$12,$20,$33,$11
            fcb     $0f,$0e,$df,$0e,$10,$11,$00,$0f
            fcb     $df,$ff,$de,$f1,$ef,$f2,$37,$12
            fcb     $f4,$2f,$dc,$d2,$dd,$03,$22,$02
            fcb     $31,$fe,$fe,$fd,$f0,$21,$23,$31
            fcb     $f2,$0e,$f0,$f0,$ff,$21,$00,$11
            fcb     $fe,$f0,$ee,$e0,$f0,$f0,$00,$ef
            fcb     $f0,$12,$71,$2e,$22,$ee,$ce,$2f
            fcb     $e1,$32,$2f,$02,$fd,$e0,$0f,$01
            fcb     $22,$20,$01,$0d,$e1,$11,$02,$21
            fcb     $ff,$f1,$fe,$01,$00,$ff,$1e,$ef
            fcb     $0f,$ff,$01,$df,$f0,$04,$71,$f1
            fcb     $11,$fd,$c0,$1f,$f1,$32,$1f,$10
            fcb     $0c,$0f,$00,$01,$21,$11,$00,$ef
            fcb     $f0,$f2,$30,$21,$0f,$0e,$00,$f0
            fcb     $20,$0f,$0f,$fe,$f0,$e0,$0f,$0f
            fcb     $f0,$ef,$f1,$77,$c0,$5f,$dd,$d1
            fcb     $2d,$f5,$3f,$00,$10,$dd,$11,$f0
            fcb     $12,$20,$f1,$0f,$ef,$01,$0f,$33
            fcb     $1f,$10,$0e,$f0,$10,$f1,$10,$ff
            fcb     $0f,$ff,$0f,$0f,$0f,$0e,$ff,$ff
            fcb     $f0,$67,$2e,$d5,$1c,$ce,$03,$ee
            fcb     $54,$ff,$10,$0d,$d0,$2f,$02,$21
            fcb     $f0,$10,$ee,$01,$0f,$02,$30,$f1
            fcb     $2f,$e0,$01,$0f,$12,$ff,$00,$0f
            fcb     $f0,$0f,$f0,$0f,$ff,$f1,$ef,$fe
            fcb     $00,$17,$6b,$14,$fc,$ee,$31,$d1
            fcb     $42,$e0,$01,$fd,$e2,$1e,$12,$10
            fcb     $0f,$10,$ef,$10,$00,$01,$10,$f1
            fcb     $1f,$11,$11,$ff,$10,$f0,$00,$0f
            fcb     $00,$0f,$f0,$0e,$0f,$00,$e0,$0f
            fcb     $ff,$ff,$14,$5f,$13,$1d,$ef,$10
            fcb     $e0,$31,$0f,$11,$fe,$f1,$0f,$f2
            fcb     $10,$00,$10,$ff,$10,$f0,$01,$00
            fcb     $00,$00,$f0,$00,$24,$fe,$21,$ef
            fcb     $01,$0f,$f2,$0f,$e0,$1f,$e0,$1f
            fcb     $f0,$00,$fe,$01,$ef,$01,$15,$20
            fcb     $20,$fe,$ff,$2f,$f1,$20,$f0,$10
            fcb     $fe,$01,$ff,$11,$10,$00,$10,$f0
            fcb     $0f,$00,$10,$0f,$1f,$00,$00,$01
            fcb     $21,$f1,$1f,$0f,$01,$ff,$11,$ff
            fcb     $00,$0e,$00,$0f,$00,$10,$fe,$10
            fcb     $e0,$ff,$00,$14,$3e,$13,$fe,$f0
            fcb     $11,$e0,$2f,$00,$01,$ff,$f1,$0f
            fcb     $01,$00,$01,$00,$00,$00,$f0,$01
            fcb     $00,$00,$f0,$00,$00,$01,$10,$02
            fcb     $0f,$00,$00,$00,$1f,$00,$f0,$0f
            fcb     $00,$00,$0f,$10,$f0,$f0,$0f,$00
            fcb     $0f,$f0,$0f,$02,$21,$01,$10,$f0
            fcb     $10,$0f,$00,$00,$00,$00,$f0,$00
            fcb     $00,$00,$00,$00,$10,$00,$00,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $01,$00,$10,$00,$01,$00,$00,$00
            fcb     $0f,$00,$00,$f0,$00,$00,$f0,$00
            fcb     $00,$f0,$00,$00,$f0,$0f,$00,$f0
            fcb     $11,$01,$01,$01,$01,$10,$00,$f0
            fcb     $00,$00,$f0,$00,$f0,$00,$00,$00
            fcb     $00,$00,$01,$00,$00,$00,$00,$00
            fcb     $f0,$00,$00,$00,$00,$00,$00,$00
            fcb     $10,$00,$01,$00,$10,$00,$00,$0f
            fcb     $00,$00,$0f,$00,$0f,$00,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$00,$0f
            fcb     $00,$f1,$10,$01,$00,$10,$10,$10
            fcb     $00,$00,$0f,$00,$f0,$0f,$00,$0f
            fcb     $10,$f1,$00,$00,$00,$10,$00,$00
            fcb     $00,$00,$00,$0f,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$10,$00,$00,$01
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$00,$0f
            fcb     $10,$0f,$00,$00,$00,$00,$10,$00
            fcb     $00,$10,$00,$1f,$10,$f0,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$00,$00,$00,$00,$00,$00
            fcb     $0f,$00,$00,$00,$00,$00,$00,$01
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $00,$00,$f0,$00,$f1,$0f,$10,$00
            fcb     $1f,$11,$00,$00,$01,$f0,$10,$f0
            fcb     $00,$00,$00,$0f,$00,$00,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$00,$00
            fcb     $f0,$00,$00,$00,$00,$00,$00,$10
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $00,$00,$00,$00,$10,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$f0,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$0f
            fcb     $00,$00,$00,$00,$01,$00,$10,$00
            fcb     $01,$00,$00,$0f,$00,$00,$00,$00
            fcb     $f0,$00,$00,$00,$00,$00,$10,$00
            fcb     $00,$00,$00,$00,$00,$00,$0f,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$10
            fcb     $00,$00,$00,$00,$00,$f1,$00,$00
            fcb     $f0,$00,$00,$00,$00,$00,$00,$10
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$00,$00
            fcb     $10,$00,$00,$00,$00,$0f,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$10,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$00,$00
            fcb     $00,$00,$01,$00,$00,$00,$00,$00
            fcb     $00,$0f,$00,$00,$00,$00,$00,$00
            fcb     $01,$f1,$00,$f1,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$0f,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$10,$00,$f0,$1f,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$0f,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$01
            fcb     $00,$f1,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$0f,$00,$00,$00,$00,$00
            fcb     $00,$01,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$0f,$00
            fcb     $00,$00,$01,$00,$00,$00,$00,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $00,$00,$10,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$f0,$00,$00,$00,$01
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$0f,$1f,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$01,$f1,$00,$00
            fcb     $0f,$1f,$10,$0f,$10,$f0,$01,$0f
            fcb     $01,$f0,$00,$00,$00,$1f,$10,$00
            fcb     $00,$0f,$00,$00,$01,$f1,$00,$0f
            fcb     $00,$00,$10,$f1,$f0,$10,$0f,$10
            fcb     $0f,$10,$f1,$f1,$f1,$f0,$01,$f1
            fcb     $0f,$10,$f0,$1f,$1f,$1f,$01,$f1
            fcb     $f0,$01,$f0,$1f,$1f,$00,$00,$00
            fcb     $01,$f0,$10,$00,$00,$00,$00,$00
            fcb     $0f,$00,$00,$01,$f1,$f1,$0f,$01
            fcb     $0f,$01,$0f,$10,$00,$00,$00,$00
            fcb     $f0,$0f,$02,$00,$f0,$1f,$1f,$10
            fcb     $00,$f1,$00,$f1,$f0,$01,$0f,$1f
            fcb     $1f,$01,$f1,$00,$f1,$f1,$f1,$f1
            fcb     $f1,$f0,$00,$1f,$1f,$1f,$1f,$1f
            fcb     $10,$f1,$f1,$f1,$f1,$f1,$0f,$01
            fcb     $f1,$f1,$0f,$1f,$1f,$1f,$1f,$1f
            fcb     $1f,$01,$f1,$f1,$f1,$f1,$f1,$f1
            fcb     $f0,$1f,$1f,$1f,$1f,$1f,$10,$00
            fcb     $f1,$f1,$f1,$0f,$10,$f1,$0f,$1f
            fcb     $10,$0f,$1f,$01,$f0,$01,$f1,$f0
            fcb     $00,$10,$f1,$00,$0f,$10,$f1,$00
            fcb     $f1,$f1,$f1,$00,$0f,$10,$f0,$1f
            fcb     $00,$10,$0f,$1f,$1f,$10,$f1,$f1
            fcb     $f1,$f1,$f0,$01,$0f,$10,$0f,$00
            fcb     $1f,$10,$00,$f1,$f1,$0f,$1f,$1f
            fcb     $1f,$10,$f1,$0f,$01,$f1,$f1,$f1
            fcb     $f1,$f1,$f1,$00,$0f,$1f,$1f,$1f
            fcb     $10,$f0,$01,$f1,$f1,$00,$0f,$10
            fcb     $f1,$f0,$01,$00,$00,$00,$0f,$1f
            fcb     $1f,$00,$1f,$1f,$10,$f0,$10,$f1
            fcb     $f1,$f1,$f1,$f1,$00,$0f,$1f,$1f
            fcb     $10,$0f,$1f,$1f,$10,$00,$0f,$00
            fcb     $10,$00,$f1,$00,$f1,$f0,$01,$00
            fcb     $f1,$0f,$01,$00,$f0,$1f,$1f,$1f
            fcb     $1f,$10,$f0,$10,$f1,$f1,$f0,$01
            fcb     $f0,$1f,$1f,$10,$0f,$01,$0f,$01
            fcb     $f1,$f1,$f1,$f1,$0f,$1f,$1f,$1f
            fcb     $1f,$1f,$10,$f1,$f1,$f1,$f1,$f1
            fcb     $f1,$f0,$1f,$1f,$1f,$1f,$1f,$1f
            fcb     $1f,$00,$01,$f1,$f1,$f1,$f0,$1f
            fcb     $10,$f1,$f0,$1f,$1f,$10,$0f,$00
            fcb     $1f,$1f,$1f,$10,$f1,$f1,$f1,$f1
            fcb     $0f,$1f,$1f,$1f,$1f,$00,$01,$f1
            fcb     $f1,$f1,$0f,$00,$10,$f0,$1f,$00
            fcb     $01,$0f,$00,$10,$00,$f1,$f1,$f1
            fcb     $f1,$f1,$f0,$1f,$1f,$1f,$1f,$00
            fcb     $10,$f1,$f0,$01,$f1,$f1,$f1,$f1
            fcb     $f1,$0f,$1f,$1f,$00,$1f,$1f,$01
            fcb     $f1,$f1,$f1,$f0,$1f,$1f,$1f,$1f
            fcb     $01,$f1,$0f,$10,$f0,$01,$0f,$1f
            fcb     $1f,$10,$f1,$f1,$f1,$00,$00,$f1
            fcb     $f0,$1f,$01,$0f,$1f,$00,$00,$10
            fcb     $f1,$f1,$f1,$f1,$f1,$0f,$1f,$1f
            fcb     $1f,$00,$10,$f1,$f1,$0f,$1f,$1f
            fcb     $1f,$01,$f1,$00,$f1,$f0,$1f,$1f
            fcb     $1f,$1f,$00,$01,$00,$f1,$f1,$f1
            fcb     $f1,$0f,$1f,$10,$0f,$1f,$1f,$1f
            fcb     $10,$f1,$f1,$f1,$f1,$f1,$f0,$1f
            fcb     $1f,$1f,$1f,$1f,$01,$f1,$f1,$f1
            fcb     $f0,$10,$0f,$00,$1f,$1f,$1f,$10
            fcb     $f1,$f1,$f1,$f1,$f1,$0f,$1f,$1f
            fcb     $10,$00,$f1,$f1,$f1,$f0,$1f,$1f
            fcb     $00,$10,$00,$0f,$01,$f0,$01,$0f
            fcb     $10,$00,$f0,$10,$f0,$00,$1f,$1f
            fcb     $1f,$1f,$01,$f1,$f1,$f1,$0f,$10
            fcb     $f1,$0f,$10,$0f,$1f,$10,$f1,$0f
            fcb     $10,$0f,$1f,$01,$f1,$0f,$10,$0f
            fcb     $1f,$01,$f0,$01,$f1,$f0,$10,$f0
            fcb     $1f,$1f,$1f,$1f,$01,$f1,$f1,$f1
            fcb     $f1,$f0,$01,$0f,$1f,$1f,$1f,$1f
            fcb     $1f,$10,$00,$f1,$f1,$00,$f0,$1f
            fcb     $1f,$01,$f1,$0f,$01,$f0,$00,$00
            fcb     $00,$00,$00,$1f,$1f,$1f,$01,$00
            fcb     $00,$0f,$1f,$00,$01,$00,$0f,$10
            fcb     $0f,$1f,$10,$00,$00,$f1,$f1,$00
            fcb     $00,$00,$0f,$1f,$1f,$1f,$01,$f1
            fcb     $f1,$f1,$f0,$00,$1f,$1f,$1f,$1f
            fcb     $1f,$00,$01,$f1,$f1,$f1,$f0,$00
            fcb     $01,$0f,$00,$1f,$00,$1f,$00,$00
            fcb     $00,$00,$01,$f1,$f1,$f0,$00,$00
            fcb     $00,$00,$1f,$1f,$10,$00,$f1,$f0
            fcb     $01,$00,$00,$00,$0f,$1f,$00,$00
            fcb     $00,$01,$00,$00,$f0,$00,$00,$00
            fcb     $10,$0f,$01,$00,$00,$0f,$00,$01
            fcb     $00,$00,$f1,$f0,$01,$00,$f0,$00
            fcb     $00,$01,$00,$00,$0f,$00,$00,$00
            fcb     $00,$00,$00,$01,$00,$0f,$00,$10
            fcb     $00,$00,$f0,$00,$10,$00,$00,$00
            fcb     $0f,$00,$00,$10,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$f1,$f0
            fcb     $00,$00,$00,$00,$01,$00,$00,$f1
            fcb     $f0,$00,$10,$00,$00,$0f,$10,$00
            fcb     $f0,$00,$00,$00,$00,$00,$1f,$00
            fcb     $00,$00,$00,$00,$00,$01,$f1,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$0f,$01,$f0,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$00,$00,$00,$f0,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$10,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $f1,$f0,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$01,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$f1
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$0f,$01,$f1,$00,$00,$00,$00
            fcb     $00,$f1,$f1,$00,$f0,$00,$00,$00
            fcb     $00,$00,$01,$f1,$f1,$0f,$10,$00
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$10,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f1,$00,$00,$00,$0f,$10,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f1,$f1,$f0,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$1f,$10
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$f1,$0f,$10
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $0f,$00,$00,$00,$00,$00,$00,$00
            fcb     $1f,$10,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $0f,$10,$00,$0f,$00,$1f,$1f,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f1,$00,$00,$00,$0f,$10,$00
            fcb     $00,$00,$0f,$10,$00,$0f,$10,$00
            fcb     $0f,$10,$f1,$00,$00,$f1,$00,$00
            fcb     $00,$00,$00,$f1,$00,$00,$00,$00
            fcb     $00,$00,$f1,$00,$0f,$10,$00,$00
            fcb     $f1,$0f,$10,$00,$00,$0f,$10,$00
            fcb     $00,$00,$00,$f1,$00,$00,$00,$0f
            fcb     $10,$0f,$1f,$10,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $f1,$0f,$1f,$10,$00,$0f,$10,$00
            fcb     $f1,$f0,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$00,$00,$00,$00,$00,$00
            fcb     $00,$f0,$10,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$f0,$00,$10,$00,$00,$00
            fcb     $00,$00,$0f,$10,$f0,$01,$f0,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$f0,$01,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f0,$01,$f1,$f1,$f0,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$0f,$23,$df,$10,$f0,$10,$ff
            fcb     $10,$1f,$10,$00,$f0,$01,$00,$11
            fcb     $d2,$1f,$0d,$1f,$00,$20,$f0,$11
            fcb     $f0,$01,$f0,$f1,$f1,$ff,$1f,$11
            fcb     $10,$0f,$1f,$0f,$1f,$00,$00,$1f
            fcb     $10,$00,$00,$01,$e1,$00,$f1,$f1
            fcb     $f0,$1f,$1f,$01,$0f,$1f,$01,$0f
            fcb     $1f,$01,$e3,$ff,$11,$f0,$00,$0f
            fcb     $00,$00,$1f,$01,$00,$01,$e1,$f1
            fcb     $f0,$01,$f1,$ff,$2f,$1f,$1f,$1f
            fcb     $10,$f0,$00,$f2,$e2,$00,$f1,$0f
            fcb     $00,$00,$00,$00,$00,$00,$00,$1f
            fcb     $01,$f0,$1e,$10,$0f,$11,$ff,$11
            fcb     $f0,$f2,$0e,$11,$ff,$10,$1f,$00
            fcb     $00,$00,$00,$00,$0f,$10,$f1,$00
            fcb     $01,$f0,$1f,$01,$f0,$01,$f0,$10
            fcb     $f1,$00,$0e,$01,$01,$0f,$10,$e1
            fcb     $10,$f0,$1f,$00,$0f,$10,$00,$01
            fcb     $0f,$10,$00,$10,$f1,$f0,$00,$00
            fcb     $01,$0e,$01,$ef,$21,$f0,$00,$00
            fcb     $00,$10,$f0,$1f,$02,$00,$0f,$01
            fcb     $f2,$2e,$e2,$0d,$02,$ee,$30,$0f
            fcb     $f0,$0f,$f1,$0f,$f1,$0f,$11,$f0
            fcb     $41,$f1,$30,$f0,$01,$1f,$11,$ff
            fcb     $1f,$01,$fe,$1f,$d0,$2f,$df,$1b
            fcb     $c2,$0f,$13,$32,$0f,$02,$21,$20
            fcb     $01,$10,$1f,$00,$11,$ec,$02,$fd
            fcb     $02,$ee,$ed,$fd,$d4,$2d,$34,$ef
            fcb     $3f,$13,$21,$22,$0f,$01,$00,$00
            fcb     $1f,$f0,$ef,$0f,$fe,$fe,$fc,$ed
            fcb     $44,$c4,$3f,$03,$fe,$32,$23,$2f
            fcb     $f1,$12,$ee,$11,$fe,$0f,$ed,$11
            fcb     $ce,$1c,$df,$05,$1d,$66,$ae,$30
            fcb     $11,$14,$3f,$e2,$20,$f0,$ef,$11
            fcb     $ed,$01,$fd,$de,$fd,$cf,$72,$4a
            fcb     $57,$cd,$20,$00,$f2,$3f,$06,$30
            fcb     $1d,$cf,$10,$f0,$0e,$fe,$fe,$dd
            fcb     $ed,$71,$7a,$27,$10,$c0,$00,$fe
            fcb     $13,$2f,$44,$3e,$cd,$0f,$02,$0e
            fcb     $ff,$ed,$ee,$ea,$67,$7a,$d7,$14
            fcb     $be,$1f,$fe,$e2,$41,$35,$4c,$de
            fcb     $ef,$02,$1e,$e0,$fd,$dd,$ea,$77
            fcb     $59,$17,$32,$9f,$3d,$df,$f2,$22
            fcb     $55,$2d,$c0,$ec,$12,$fe,$f1,$fe
            fcb     $dd,$c1,$74,$ec,$71,$5d,$d3,$1c
            fcb     $c0,$10,$13,$53,$1d,$10,$bf,$2f
            fcb     $d0,$0f,$e0,$dc,$e7,$68,$37,$10
            fcb     $c2,$3e,$cf,$f2,$ff,$63,$02,$2e
            fcb     $e0,$fe,$ff,$e0,$0d,$fd,$e1,$7f
            fcb     $b7,$24,$b0,$5f,$df,$0f,$0f,$06
            fcb     $f0,$41,$d1,$2c,$00,$ee,$0f,$df
            fcb     $ef,$23,$d2,$6f,$d5,$3b,$02,$fd
            fcb     $01,$00,$12,$1f,$21,$ff,$1f,$ef
            fcb     $0f,$ef,$0d,$e3,$3c,$07,$0c,$44
            fcb     $cf,$4f,$ef,$01,$0f,$11,$f1,$10
            fcb     $0f,$01,$ff,$0f,$f0,$00,$00,$10
            fcb     $10,$f1,$0f,$01,$fe,$21,$e1,$10
            fcb     $f2,$0f,$01,$0f,$00,$00,$00,$00
            fcb     $00,$00,$00,$f1,$0f,$10,$f0,$00
            fcb     $00,$00,$00,$00,$00,$01,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$0f
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $00,$00,$10,$00,$00,$00,$00,$0f
            fcb     $00,$00,$01,$f0,$00,$00,$00,$10
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$f0,$00,$00,$10,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$f0
            fcb     $00,$01,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$01,$00
            fcb     $00,$0f,$00,$00,$00,$10,$00,$0f
            fcb     $00,$00,$00,$01,$00,$00,$0f,$00
            fcb     $00,$01,$f1,$00,$00,$00,$00,$00
            fcb     $00,$f0,$00,$00,$00,$01,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$f0
            fcb     $00,$1f,$00,$00,$00,$00,$00,$00
            fcb     $01,$f1,$00,$f0,$01,$f1,$f0,$10
            fcb     $0f,$00,$1f,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$01,$00,$1f,$e0,$20,$e0
            fcb     $21,$0d,$05,$fc,$f1,$03,$0e,$13
            fcb     $fc,$02,$ff,$13,$0b,$05,$fd,$12
            fcb     $e0,$20,$fe,$02,$ff,$21,$d0,$21
            fcb     $e0,$10,$f0,$10,$f0,$10,$f0,$0f
            fcb     $10,$00,$00,$01,$00,$0f,$00,$f1
            fcb     $00,$00,$f2,$0f,$02,$10,$f0,$0e
            fcb     $f2,$1f,$e0,$10,$f0,$20,$00,$01
            fcb     $f0,$f0,$2f,$e0,$11,$0f,$f2,$0f
            fcb     $01,$0f,$01,$0f,$f2,$0f,$01,$0f
            fcb     $10,$00,$0f,$10,$f0,$01,$f0,$01
            fcb     $0f,$01,$0f,$01,$0f,$10,$f1,$f0
            fcb     $1f,$10,$f1,$f0,$10,$f1,$00,$f0
            fcb     $10,$f0,$1f,$10,$f0,$1f,$00,$1f
            fcb     $f2,$f1,$e1,$10,$f0,$10,$f0,$10
            fcb     $0e,$20,$0f,$1f,$10,$00,$f1,$00
            fcb     $f1,$00,$f1,$0f,$10,$0f,$1f,$1f
            fcb     $00,$10,$f1,$f0,$00,$01,$00,$f1
            fcb     $00,$f0,$1f,$1f,$10,$f0,$01,$0f
            fcb     $00,$1f,$01,$00,$f1,$f1,$f1,$f0
            fcb     $1f,$1f,$1f,$1f,$01,$f0,$10,$f1
            fcb     $f1,$00,$f1,$0f,$1f,$1f,$1f,$1f
            fcb     $00,$10,$f1,$00,$f0,$01,$f0,$10
            fcb     $0f,$1f,$10,$f0,$01,$f0,$01,$0f
            fcb     $01,$0f,$01,$0f,$10,$0f,$1f,$1f
            fcb     $10,$00,$f1,$f1,$f1,$00,$f1,$00
            fcb     $0f,$10,$0f,$1f,$1f,$1f,$10,$f1
            fcb     $f1,$f1,$f1,$00,$f1,$00,$0f,$10
            fcb     $0f,$10,$00,$0f,$10,$0f,$10,$0f
            fcb     $01,$00,$f1,$f1,$f1,$f0,$1f,$1f
            fcb     $1f,$10,$00,$00,$f1,$f1,$f1,$f1
            fcb     $0f,$1f,$1f,$1f,$10,$f1,$f1,$f1
            fcb     $f1,$f0,$1f,$00,$1f,$1f,$1f,$01
            fcb     $f0,$00,$00,$00,$00,$00,$00,$00
            fcb     $10,$00,$00,$00,$f0,$1f,$1f,$1f
            fcb     $10,$f1,$f1,$f1,$00,$0f,$1f,$10
            fcb     $00,$00,$00,$0f,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$10,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$01,$f1
            fcb     $00,$00,$00,$f1,$00,$00,$0f,$01
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$f0,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$01,$f0,$10,$00,$00,$00
            fcb     $00,$0f,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$0f,$00,$00,$0f,$00,$00,$f0
            fcb     $0f,$00,$00,$00,$01,$01,$10,$11
            fcb     $10,$11,$01,$00,$00,$00,$0f,$0f
            fcb     $0f,$0f,$0f,$f0,$ff,$ff,$f0,$ff
            fcb     $ff,$f0,$11,$12,$11,$22,$12,$10
            fcb     $01,$f0,$f0,$f0,$f0,$00,$f0,$10
            fcb     $11,$10,$11,$00,$00,$00,$ff,$fe
            fcb     $ff,$ff,$ef,$ef,$ef,$ff,$11,$12
            fcb     $12,$22,$22,$21,$01,$0f,$0f,$ff
            fcb     $0f,$f0,$ff,$00,$01,$10,$12,$11
            fcb     $11,$01,$00,$0f,$ff,$fe,$fe,$ff
            fcb     $ef,$ee,$fe,$ff,$11,$11,$21,$23
            fcb     $32,$11,$11,$10,$f0,$ef,$0f,$0f
            fcb     $ff,$ff,$01,$00,$11,$12,$11,$11
            fcb     $10,$00,$0f,$ff,$fe,$ff,$ef,$fe
            fcb     $ef,$fe,$fe,$12,$01,$21,$22,$42
            fcb     $21,$01,$01,$0f,$ff,$f0,$ff,$ff
            fcb     $ef,$00,$01,$00,$12,$12,$21,$11
            fcb     $01,$00,$ff,$ff,$ef,$fe,$fe,$fe
            fcb     $fe,$ff,$fe,$21,$11,$12,$13,$33
            fcb     $11,$01,$01,$00,$ee,$f0,$ff,$ff
            fcb     $ef,$00,$01,$01,$01,$23,$12,$10
            fcb     $11,$01,$ff,$fe,$ff,$ff,$ee,$ff
            fcb     $fe,$ff,$fe,$f2,$10,$12,$11,$24
            fcb     $21,$20,$00,$10,$0f,$ef,$ff,$f0
            fcb     $fe,$ff,$01,$10,$01,$11,$22,$22
            fcb     $01,$10,$10,$ff,$fe,$ff,$fe,$fe
            fcb     $ff,$0f,$ff,$ef,$f0,$02,$10,$01
            fcb     $12,$43,$11,$1f,$11,$10,$ee,$ff
            fcb     $f0,$ff,$ef,$00,$01,$00,$11,$12
            fcb     $22,$13,$30,$fe,$00,$f0,$ee,$ef
            fcb     $ff,$ed,$de,$ff,$de,$f1,$71,$76
            fcb     $2d,$f1,$23,$fb,$bd,$25,$21,$de
            fcb     $f3,$20,$db,$e1,$42,$0f,$e2,$44
            fcb     $2e,$c0,$33,$3e,$dd,$02,$20,$ee
            fcb     $f0,$10,$de,$df,$00,$fd,$de,$00
            fcb     $37,$34,$30,$b1,$00,$0d,$cf,$24
            fcb     $41,$ed,$00,$20,$cc,$f2,$43,$0e
            fcb     $02,$33,$fc,$d0,$34,$1f,$e0,$21
            fcb     $0e,$ef,$11,$0e,$ef,$00,$ff,$df
            fcb     $e0,$ff,$ee,$07,$27,$34,$0a,$df
            fcb     $21,$ec,$c1,$66,$2e,$ce,$12,$0d
            fcb     $be,$26,$30,$fe,$14,$2f,$dd,$f4
            fcb     $41,$fe,$f2,$20,$ee,$f1,$2f,$fe
            fcb     $f0,$0f,$ee,$ff,$0e,$de,$00,$67
            fcb     $52,$fe,$b2,$10,$dd,$e0,$65,$ff
            fcb     $ee,$31,$fb,$ef,$16,$1f,$ff,$33
            fcb     $2e,$df,$03,$3f,$f0,$02,$2f,$ef
            fcb     $f1,$1f,$ef,$f0,$0f,$fe,$fe,$0f
            fcb     $de,$0e,$47,$62,$2e,$a2,$10,$dd
            fcb     $ef,$64,$00,$ef,$31,$fb,$df,$24
            fcb     $1e,$00,$34,$1e,$df,$13,$1f,$f0
            fcb     $22,$1e,$ef,$11,$0f,$ef,$01,$fe
            fcb     $ef,$0f,$fe,$ef,$ff,$f4,$74,$4f
            fcb     $ee,$11,$0c,$ce,$15,$4f,$e0,$22
            fcb     $1d,$bd,$12,$20,$e0,$34,$30,$de
            fcb     $02,$00,$0f,$12,$2f,$f0,$01,$0f
            fcb     $ef,$00,$0f,$d0,$f0,$ff,$ef,$ff
            fcb     $ef,$d7,$73,$31,$de,$12,$0b,$dd
            fcb     $05,$3f,$f0,$32,$2d,$be,$02,$1f
            fcb     $e0,$34,$31,$de,$01,$10,$ef,$23
            fcb     $20,$ef,$02,$1f,$ee,$01,$0e,$ee
            fcb     $01,$0e,$ef,$f0,$fe,$ee,$77,$11
            fcb     $2d,$11,$20,$ae,$e0,$31,$ff,$23
            fcb     $21,$ed,$f1,$0f,$ee,$04,$22,$00
            fcb     $02,$00,$ff,$f2,$10,$0f,$11,$20
            fcb     $ff,$f0,$1f,$ee,$ff,$0f,$ff,$f0
            fcb     $0f,$fd,$ff,$17,$5f,$11,$21,$1d
            fcb     $ce,$00,$1e,$f1,$34,$00,$0e,$11
            fcb     $ed,$e0,$02,$10,$11,$31,$01,$e0
            fcb     $2f,$0f,$00,$11,$00,$00,$10,$fe
            fcb     $ff,$ff,$fe,$f0,$f0,$0f,$ff,$ff
            fcb     $e4,$51,$20,$22,$21,$dd,$ff,$0f
            fcb     $fe,$03,$12,$1f,$11,$1f,$ef,$e0
            fcb     $10,$0f,$11,$12,$00,$11,$11,$0f
            fcb     $0f,$00,$00,$00,$10,$f0,$f0,$ff
            fcb     $fe,$ff,$ff,$f0,$ff,$ff,$f3,$31
            fcb     $11,$32,$21,$ef,$00,$fe,$ef,$f1
            fcb     $00,$01,$12,$11,$f0,$00,$0f,$f0
            fcb     $00,$00,$f1,$12,$11,$01,$10,$1f
            fcb     $00,$f0,$0f,$f0,$f0,$0f,$0f,$f0
            fcb     $ff,$ff,$ff,$ff,$ff,$f1,$31,$02
            fcb     $22,$22,$1f,$10,$0f,$ef,$e0,$0f
            fcb     $f0,$01,$10,$01,$10,$10,$00,$00
            fcb     $0f,$0f,$01,$00,$11,$11,$10,$11
            fcb     $00,$0f,$0f,$ff,$0f,$f0,$ff,$0f
            fcb     $0f,$0f,$ff,$0f,$fe,$f0,$12,$01
            fcb     $12,$22,$20,$11,$10,$ff,$0e,$0f
            fcb     $fe,$00,$0f,$00,$10,$11,$01,$01
            fcb     $00,$00,$00,$0f,$10,$01,$10,$10
            fcb     $10,$10,$f0,$0f,$0f,$f0,$f0,$f0
            fcb     $f0,$00,$f0,$f0,$0f,$f0,$ff,$0f
            fcb     $e0,$11,$1f,$23,$11,$21,$11,$20
            fcb     $ff,$00,$ef,$ff,$f0,$ff,$00,$00
            fcb     $01,$01,$10,$10,$11,$00,$00,$10
            fcb     $f1,$00,$00,$0f,$00,$00,$f1,$f0
            fcb     $00,$00,$f0,$00,$0f,$00,$00,$00
            fcb     $0f,$00,$00,$f0,$0f,$0f,$00,$00
            fcb     $01,$01,$01,$10,$10,$01,$00,$00
            fcb     $01,$00,$f0,$00,$0f,$00,$0f,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $01,$00,$10,$01,$00,$00,$00,$00
            fcb     $f0,$00,$0f,$00,$00,$00,$00,$00
            fcb     $00,$f0,$00,$00,$f0,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$01,$00
            fcb     $01,$00,$00,$10,$00,$01,$00,$00
            fcb     $00,$00,$f0,$00,$00,$f0,$00,$00
            fcb     $00,$00,$00,$00,$00,$10,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$0f,$00
            fcb     $00,$00,$0f,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $00,$00,$00,$10,$00,$00,$00,$00
            fcb     $00,$00,$10,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$f1,$10,$00,$00,$00
            fcb     $00,$0f,$00,$00,$0f,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $11,$ff,$00,$00,$01,$00,$0f,$00
            fcb     $00,$00,$10,$0f,$00,$00,$00,$01
            fcb     $00,$00,$0f,$00,$00,$01,$00,$f0
            fcb     $00,$00,$10,$00,$00,$00,$00,$0f
            fcb     $00,$00,$00,$00,$01,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$0f,$00,$00,$01,$00,$00
            fcb     $00,$00,$00,$00,$0f,$01,$f0,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $01,$00,$01,$00,$00,$00,$00,$00
            fcb     $01,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$f0,$00,$00,$00
            fcb     $0f,$00,$00,$00,$00,$00,$f0,$00
            fcb     $0f,$0f,$00,$f0,$10,$01,$01,$11
            fcb     $01,$00,$00,$00,$00,$f0,$0f,$00
            fcb     $00,$f0,$00,$01,$00,$10,$10,$11
            fcb     $00,$10,$00,$0f,$00,$f0,$0f,$00
            fcb     $0f,$00,$00,$f0,$00,$00,$0f,$00
            fcb     $0f,$0f,$0f,$f0,$f1,$00,$11,$01
            fcb     $12,$10,$10,$10,$0f,$0f,$00,$f0
            fcb     $0f,$00,$0f,$00,$00,$00,$00,$01
            fcb     $00,$00,$01,$01,$01,$01,$00,$10
            fcb     $00,$00,$0f,$00,$f0,$f0,$0f,$00
            fcb     $f0,$0f,$00,$f0,$f0,$f0,$ff,$0f
            fcb     $11,$01,$10,$12,$11,$11,$00,$00
            fcb     $f0,$f0,$f0,$00,$f0,$f0,$00,$00
            fcb     $00,$00,$00,$10,$00,$01,$00,$00
            fcb     $00,$10,$10,$10,$01,$00,$00,$00
            fcb     $f0,$0f,$0f,$0f,$00,$f0,$f0,$f0
            fcb     $0f,$0f,$0f,$0f,$f1,$10,$01,$10
            fcb     $21,$20,$10,$10,$00,$0f,$0f,$00
            fcb     $f0,$ff,$00,$00,$f0,$00,$10,$01
            fcb     $00,$01,$00,$00,$00,$00,$10,$01
            fcb     $00,$10,$01,$00,$00,$0f,$00,$f0
            fcb     $f0,$f0,$ff,$00,$f0,$0f,$00,$f0
            fcb     $f0,$ff,$20,$01,$11,$02,$20,$11
            fcb     $00,$01,$ff,$0f,$00,$0f,$ff,$0f
            fcb     $00,$00,$00,$01,$10,$00,$10,$10
            fcb     $0f,$10,$00,$f0,$01,$00,$01,$00
            fcb     $10,$01,$00,$00,$0f,$0f,$0f,$0f
            fcb     $f0,$f0,$0f,$0f,$0f,$0f,$f0,$f0
            fcb     $20,$00,$12,$12,$11,$01,$10,$00
            fcb     $ff,$0f,$0f,$ff,$00,$0f,$0f,$10
            fcb     $10,$00,$11,$10,$00,$00,$0f,$f1
            fcb     $f0,$00,$22,$00,$10,$00,$f0,$10
            fcb     $f1,$00,$f0,$ff,$ff,$f0,$e0,$11
            fcb     $ef,$1f,$ef,$ee,$27,$41,$c2,$14
            fcb     $0c,$b0,$40,$df,$13,$4e,$e1,$2f
            fcb     $de,$f1,$2f,$e3,$31,$ff,$01,$fd
            fcb     $f0,$10,$00,$12,$0f,$00,$ff,$00
            fcb     $04,$e2,$6d,$f1,$ff,$0f,$f2,$1e
            fcb     $11,$ff,$ff,$10,$df,$10,$ff,$01
            fcb     $1e,$d2,$ff,$ef,$f6,$76,$8f,$06
            fcb     $e2,$ac,$04,$29,$25,$12,$ed,$32
            fcb     $cb,$02,$10,$f1,$41,$ef,$20,$ed
            fcb     $01,$1f,$f2,$10,$f0,$11,$ee,$10
            fcb     $01,$07,$48,$32,$ef,$df,$22,$ef
            fcb     $32,$df,$f0,$0e,$e2,$2e,$f0,$f1
            fcb     $fe,$1f,$f1,$ff,$f0,$e3,$77,$9c
            fcb     $73,$d1,$be,$02,$19,$37,$ef,$10
            fcb     $20,$be,$30,$c1,$22,$10,$f2,$1e
            fcb     $e0,$f0,$f0,$12,$f0,$01,$00,$ff
            fcb     $12,$1f,$22,$1e,$01,$0d,$01,$0f
            fcb     $f0,$20,$ef,$20,$d0,$00,$0d,$f2
            fcb     $1d,$02,$ff,$fe,$ff,$22,$54,$c3
            fcb     $6b,$d0,$1c,$e2,$00,$20,$22,$0f
            fcb     $0f,$ef,$0f,$f0,$11,$12,$10,$00
            fcb     $ff,$e0,$ff,$01,$10,$12,$00,$71
            fcb     $ac,$71,$ae,$50,$d2,$02,$0d,$02
            fcb     $0c,$02,$ee,$10,$ff,$1f,$0f,$02
            fcb     $fe,$1f,$ff,$0f,$f4,$6b,$07,$4f
            fcb     $93,$5b,$b3,$0d,$f1,$11,$0f,$32
            fcb     $d0,$3f,$c0,$2e,$e1,$2f,$02,$10
            fcb     $f0,$1f,$e1,$0e,$01,$1f,$12,$21
            fcb     $1f,$3f,$e0,$1e,$e2,$fe,$11,$ff
            fcb     $11,$ff,$00,$ff,$f1,$0e,$01,$ff
            fcb     $11,$ef,$1f,$e2,$4b,$26,$fd,$45
            fcb     $b0,$4f,$d0,$2d,$f0,$f0,$0f,$11
            fcb     $e0,$3f,$f1,$2e,$02,$0f,$10,$f0
            fcb     $00,$f0,$00,$00,$00,$10,$11,$01
            fcb     $01,$00,$00,$f0,$f0,$f0,$f0,$f0
            fcb     $00,$0f,$00,$00,$00,$00,$00,$f1
            fcb     $0f,$00,$0f,$01,$00,$01,$00,$20
            fcb     $00,$10,$00,$00,$00,$f0,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$00,$00
            fcb     $00,$10,$00,$00,$00,$00,$00,$00
            fcb     $10,$00,$10,$00,$0f,$00,$00,$f0
            fcb     $00,$0f,$00,$00,$00,$00,$00,$00
            fcb     $f0,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$01,$00,$10,$00,$10,$00,$00
            fcb     $00,$0f,$00,$00,$00,$0f,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$01
            fcb     $00,$10,$00,$00,$00,$00,$00,$00
            fcb     $0f,$00,$00,$00,$00,$00,$00,$00
            fcb     $0f,$00,$00,$00,$0f,$00,$00,$00
            fcb     $00,$00,$01,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$01,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$0f,$00,$00
            fcb     $10,$f0,$10,$00,$10,$00,$00,$00
            fcb     $00,$f0,$00,$00,$00,$00,$f0,$00
            fcb     $00,$1f,$01,$01,$2c,$e3,$1d,$f3
            fcb     $0e,$f1,$1f,$00,$01,$f0,$10,$f1
            fcb     $00,$00,$00,$00,$1f,$01,$f0,$01
            fcb     $f0,$10,$00,$00,$00,$00,$00,$01
            fcb     $00,$01,$00,$1f,$00,$0f,$00,$0f
            fcb     $00,$f0,$00,$0f,$00,$00,$f0,$0f
            fcb     $f1,$ff,$20,$f2,$11,$02,$10,$10
            fcb     $0f,$0e,$f0,$e0,$00,$f1,$01,$11
            fcb     $01,$1f,$01,$0f,$00,$f0,$00,$10
            fcb     $02,$00,$10,$00,$f0,$ff,$ff,$0f
            fcb     $f0,$00,$f1,$10,$f0,$f0,$ef,$e5
            fcb     $38,$56,$0b,$46,$cf,$01,$fd,$ee
            fcb     $3d,$d3,$2f,$03,$21,$00,$11,$fe
            fcb     $10,$df,$01,$e0,$21,$30,$03,$1f
            fcb     $f2,$ef,$ff,$ff,$ff,$01,$f0,$10
            fcb     $f0,$0f,$fe,$fe,$e0,$61,$b5,$71
            fcb     $fd,$43,$ee,$ff,$0d,$cf,$3f,$d2
            fcb     $31,$12,$21,$1e,$f1,$ff,$ef,$00
            fcb     $ff,$23,$10,$23,$01,$f0,$0e,$ef
            fcb     $0e,$f0,$00,$00,$00,$00,$f0,$ff
            fcb     $ef,$ec,$27,$28,$f7,$23,$f0,$5f
            fcb     $4e,$b3,$1b,$b2,$0d,$0e,$23,$0e
            fcb     $34,$0f,$12,$1f,$ef,$2f,$ee,$33
            fcb     $d0,$13,$ef,$01,$1e,$f1,$0f,$f0
            fcb     $00,$0e,$11,$f0,$f0,$00,$ff,$1f
            fcb     $0f,$00,$00,$11,$f1,$10,$01,$00
            fcb     $10,$00,$00,$00,$00,$1f,$10,$f0
            fcb     $00,$f0,$00,$00,$00,$00,$01,$00
            fcb     $10,$00,$10,$00,$01,$0f,$00,$00
            fcb     $f0,$00,$f0,$00,$f0,$0f,$00,$00
            fcb     $0f,$00,$00,$00,$00,$00,$00,$00
            fcb     $01,$01,$00,$10,$00,$00,$10,$00
            fcb     $00,$00,$f0,$00,$00,$f0,$00,$00
            fcb     $00,$00,$01,$01,$01,$00,$10,$0f
            fcb     $00,$0f,$00,$f0,$00,$f0,$00,$0f
            fcb     $00,$00,$00,$01,$00,$00,$00,$0f
            fcb     $00,$00,$00,$00,$00,$00,$00,$10
            fcb     $00,$10,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$0f,$00,$00,$00,$01
            fcb     $00,$00,$00,$01,$00,$00,$00,$00
            fcb     $f0,$00,$00,$0f,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$f0,$00,$00,$10,$00,$00
            fcb     $00,$01,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$f0,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$10,$00,$00,$00,$00,$0f
            fcb     $00,$00,$00,$00,$10,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$0f
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$01,$f1,$f1,$00,$00
            fcb     $00,$0f,$1f,$1f,$1f,$1f,$1f,$00
            fcb     $1f,$03,$fe,$1f,$00,$10,$ff,$10
            fcb     $1f,$00,$10,$ff,$11,$e2,$2f,$e1
            fcb     $01,$0e,$00,$1f,$11,$f0,$f1,$00
            fcb     $f1,$0f,$10,$0f,$00,$01,$00,$10
            fcb     $f0,$00,$0f,$01,$00,$00,$f1,$f0
            fcb     $01,$f0,$00,$00,$00,$1f,$00,$00
            fcb     $f1,$00,$f0,$1f,$00,$10,$f1,$f1
            fcb     $00,$f1,$00,$01,$00,$00,$10,$01
            fcb     $00,$01,$0f,$1f,$01,$f0,$00,$f0
            fcb     $0f,$00,$f0,$0f,$f1,$ff,$0f,$0f
            fcb     $ff,$31,$d3,$31,$f1,$21,$0e,$01
            fcb     $fd,$00,$f0,$e1,$11,$f0,$31,$00
            fcb     $11,$1e,$03,$0f,$f1,$01,$e0,$11
            fcb     $ef,$10,$fe,$f1,$fe,$e0,$00,$ef
            fcb     $0f,$f0,$05,$3d,$26,$2e,$01,$00
            fcb     $be,$2f,$b0,$11,$11,$04,$3e,$02
            fcb     $1e,$ef,$0f,$fd,$14,$02,$23,$22
            fcb     $ef,$1e,$dd,$0f,$fe,$f2,$1f,$f2
            fcb     $0f,$fe,$fe,$ed,$00,$56,$d4,$64
            fcb     $ef,$0f,$f9,$d0,$0c,$03,$33,$11
            fcb     $43,$ed,$00,$dc,$e1,$1f,$03,$61
            fcb     $02,$50,$ce,$00,$cc,$12,$0e,$23
            fcb     $1e,$f0,$0d,$ce,$0f,$ee,$01,$1f
            fcb     $47,$40,$c4,$6d,$be,$f0,$da,$f5
            fcb     $1e,$35,$31,$ff,$20,$bc,$00,$e0
            fcb     $13,$32,$02,$40,$df,$00,$fd,$f2
            fcb     $1f,$f2,$21,$ef,$00,$dc,$f1,$ee
            fcb     $f1,$2e,$d0,$30,$74,$d4,$20,$dd
            fcb     $df,$fc,$e3,$42,$13,$42,$ed,$ef
            fcb     $dd,$e0,$31,$23,$52,$e0,$0f,$cf
            fcb     $2f,$00,$31,$00,$01,$0e,$e1,$fe
            fcb     $ef,$0f,$f0,$00,$ff,$0f,$df,$27
            fcb     $35,$94,$32,$bb,$e1,$2a,$e5,$51
            fcb     $f2,$22,$ea,$e2,$fd,$f2,$42,$02
            fcb     $31,$dd,$11,$ff,$12,$2f,$f1,$1e
            fcb     $f0,$1f,$ff,$0f,$ef,$01,$ff,$01
            fcb     $ee,$0f,$ed,$07,$37,$2a,$f6,$3c
            fcb     $ad,$f4,$db,$37,$2f,$01,$20,$bc
            fcb     $12,$ef,$13,$40,$f2,$2e,$de,$13
            fcb     $f0,$13,$1e,$f0,$1f,$e0,$11,$fe
            fcb     $00,$0e,$e0,$1f,$ff,$0f,$fe,$ff
            fcb     $00,$74,$69,$33,$1b,$dc,$03,$df
            fcb     $35,$10,$00,$1f,$cd,$11,$00,$12
            fcb     $21,$f0,$1f,$e0,$f1,$32,$f0,$11
            fcb     $ff,$f0,$00,$f1,$00,$ff,$f0,$0e
            fcb     $f0,$0f,$ff,$0f,$fe,$ff,$27,$44
            fcb     $c0,$41,$bc,$c1,$3f,$e3,$52,$ff
            fcb     $f0,$0d,$d0,$21,$10,$11,$2f,$ff
            fcb     $1f,$00,$12,$11,$f0,$00,$0f,$00
            fcb     $10,$f0,$00,$ff,$f0,$0f,$ff,$00
            fcb     $fe,$ff,$ff,$ff,$27,$35,$d0,$01
            fcb     $fd,$bf,$32,$00,$12,$30,$ed,$00
            fcb     $ff,$f1,$21,$0f,$02,$10,$ef,$01
            fcb     $01,$01,$21,$0f,$00,$00,$0f,$00
            fcb     $0f,$00,$f0,$ff,$0f,$f0,$f0,$1f
            fcb     $ff,$ff,$ff,$14,$42,$e0,$11,$1f
            fcb     $fe,$01,$10,$ff,$01,$10,$0f,$00
            fcb     $10,$0f,$00,$01,$00,$00,$00,$00
            fcb     $f0,$10,$10,$01,$01,$01,$00,$00
            fcb     $0f,$0f,$00,$0f,$0f,$0f,$0f,$0f
            fcb     $0f,$f0,$f0,$f0,$f1,$10,$01,$10
            fcb     $12,$11,$10,$10,$10,$f0,$f0,$00
            fcb     $ff,$0f,$f0,$00,$0f,$00,$01,$00
            fcb     $00,$10,$10,$10,$11,$10,$10,$00
            fcb     $0f,$0f,$0f,$0f,$0f,$0f,$00,$f0
            fcb     $00,$00,$f0,$f0,$0f,$0f,$f0,$11
            fcb     $00,$10,$12,$20,$10,$01,$10,$f0
            fcb     $ff,$00,$0f,$0f,$f0,$00,$f0,$00
            fcb     $01,$00,$10,$01,$01,$00,$00,$01
            fcb     $01,$00,$00,$00,$00,$0f,$00,$0f
            fcb     $0f,$00,$f0,$0f,$00,$f0,$00,$f0
            fcb     $00,$f0,$ff,$21,$00,$10,$02,$21
            fcb     $01,$f0,$01,$00,$ff,$0f,$00,$00
            fcb     $ff,$00,$00,$00,$00,$01,$01,$00
            fcb     $00,$00,$00,$00,$00,$10,$00,$01
            fcb     $00,$1f,$00,$01,$f0,$f0,$f0,$0f
            fcb     $0f,$f0,$00,$0f,$f0,$01,$00,$00
            fcb     $01,$21,$00,$10,$01,$10,$ff,$00
            fcb     $00,$f0,$f0,$f0,$00,$00,$00,$00
            fcb     $10,$00,$01,$00,$00,$00,$00,$10
            fcb     $00,$00,$00,$10,$0f,$00,$00,$0f
            fcb     $0f,$00,$00,$f0,$f0,$00,$00,$00
            fcb     $00,$11,$00,$00,$11,$00,$00,$00
            fcb     $00,$0f,$0f,$00,$00,$00,$f0,$00
            fcb     $10,$0f,$01,$00,$10,$00,$00,$00
            fcb     $00,$f0,$00,$00,$01,$00,$11,$10
            fcb     $0f,$01,$00,$0f,$f0,$00,$0f,$f0
            fcb     $f0,$00,$f0,$00,$00,$01,$f0,$00
            fcb     $00,$00,$0f,$12,$21,$f0,$f0,$01
            fcb     $0f,$f0,$01,$11,$ff,$f0,$01,$0f
            fcb     $f0,$01,$10,$00,$00,$00,$00,$f0
            fcb     $00,$10,$0f,$00,$00,$0f,$0f,$00
            fcb     $32,$1f,$ff,$00,$10,$0f,$21,$1f
            fcb     $ff,$f0,$10,$fe,$01,$20,$0e,$f0
            fcb     $10,$0f,$ff,$11,$1f,$ff,$00,$1f
            fcb     $02,$31,$1e,$d0,$02,$0f,$f0,$22
            fcb     $10,$ee,$f1,$10,$ff,$01,$21,$ff
            fcb     $f0,$10,$0f,$f1,$11,$0f,$ff,$10
            fcb     $00,$f0,$10,$10,$f0,$00,$00,$0f
            fcb     $10,$11,$02,$1f,$0e,$e0,$11,$10
            fcb     $f0,$00,$0f,$ff,$01,$01,$f0,$00
            fcb     $1f,$0f,$01,$01,$ff,$00,$10,$ff
            fcb     $00,$00,$11,$20,$0f,$f0,$00,$00
            fcb     $01,$10,$1f,$ff,$00,$00,$00,$10
            fcb     $1f,$f0,$00,$00,$00,$01,$10,$ff
            fcb     $00,$01,$f0,$01,$00,$0f,$f1,$00
            fcb     $00,$00,$10,$00,$00,$10,$ff,$f2
            fcb     $40,$0d,$e0,$11,$00,$f0,$11,$ff
            fcb     $e0,$11,$00,$ff,$11,$00,$ff,$11
            fcb     $00,$ff,$11,$0f,$ff,$01,$00,$2e
            fcb     $10,$f1,$f1,$01,$ff,$11,$01,$ff
            fcb     $00,$10,$f0,$01,$00,$0f,$00,$01
            fcb     $f0,$01,$00,$0f,$00,$10,$0f,$01
            fcb     $00,$0f,$00,$10,$f0,$00,$10,$0f
            fcb     $00,$10,$0f,$f1,$30,$0f,$f0,$11
            fcb     $f0,$ff,$20,$00,$ff,$10,$00,$f0
            fcb     $10,$0f,$00,$01,$00,$ff,$11,$0f
            fcb     $0f,$01,$1f,$f0,$10,$0f,$fe,$23
            fcb     $21,$df,$f0,$11,$fe,$02,$21,$fe
            fcb     $00,$01,$0f,$f1,$11,$0f,$f0,$10
            fcb     $0f,$f1,$01,$1f,$f0,$01,$0f,$00
            fcb     $01,$00,$0f,$00,$10,$f0,$00,$10
            fcb     $f0,$00,$01,$00,$00,$00,$00,$00
            fcb     $02,$1f,$fe,$f1,$11,$f0,$00,$10
            fcb     $ff,$f0,$10,$00,$00,$10,$0f,$0f
            fcb     $11,$f0,$00,$01,$0f,$00,$00,$00
            fcb     $00,$00,$1f,$00,$f1,$00,$00,$00
            fcb     $00,$00,$00,$01,$00,$00,$00,$00
            fcb     $f0,$01,$00,$00,$00,$f0,$00,$00
            fcb     $00,$10,$00,$0f,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$01,$10,$f0
            fcb     $00,$00,$00,$00,$01,$f0,$00,$00
            fcb     $0f,$01,$00,$00,$00,$00,$00,$f0
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $1f,$01,$f0,$00,$00,$00,$f0,$00
            fcb     $ff,$31,$11,$ef,$1f,$1f,$f0,$02
            fcb     $01,$ff,$11,$0f,$ff,$01,$10,$0f
            fcb     $11,$00,$ff,$00,$10,$f0,$00,$11
            fcb     $ff,$00,$10,$f0,$00,$01,$00,$f0
            fcb     $10,$0f,$00,$00,$1f,$00,$10,$00
            fcb     $f0,$00,$1f,$00,$00,$10,$00,$00
            fcb     $00,$0f,$00,$10,$00,$00,$00,$00
            fcb     $f1,$0f,$00,$01,$00,$00,$00,$0f
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$10,$0f,$0f,$10
            fcb     $00,$f1,$01,$00,$f0,$10,$0f,$00
            fcb     $01,$00,$f1,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$0f,$10,$00
            fcb     $00,$00,$00,$f0,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$10,$00,$10,$00
            fcb     $0f,$00,$00,$00,$01,$0f,$00,$0f
            fcb     $1f,$00,$00,$01,$f0,$00,$01,$f0
            fcb     $00,$00,$00,$00,$1f,$00,$00,$00
            fcb     $00,$00,$10,$0f,$00,$10,$00,$f1
            fcb     $00,$0f,$00,$00,$00,$00,$01,$00
            fcb     $00,$00,$f0,$00,$00,$00,$10,$00
            fcb     $00,$00,$f0,$00,$00,$00,$10,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $00,$00,$01,$10,$00,$f0,$10,$f0
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $0f,$00,$00,$00,$00,$00,$10,$0f
            fcb     $00,$00,$00,$00,$00,$00,$01,$00
            fcb     $00,$00,$f0,$00,$00,$00,$10,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$01,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$0f,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$1f,$10,$00,$00
            fcb     $0f,$00,$00,$00,$00,$01,$00,$00
            fcb     $00,$00,$f0,$00,$00,$00,$00,$10
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$0f,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$01,$00,$0f,$00
            fcb     $00,$01,$00,$f1,$00,$00,$0f,$01
            fcb     $00,$0f,$01,$00,$00,$00,$00,$00
            fcb     $00,$00,$f0,$01,$00,$00,$00,$00
            fcb     $00,$f0,$00,$00,$01,$0f,$00,$01
            fcb     $00,$00,$f0,$00,$00,$00,$00,$00
            fcb     $10,$00,$00,$00,$f0,$00,$00,$00
            fcb     $00,$10,$00,$0f,$00,$10,$00,$f0
            fcb     $00,$00,$01,$00,$00,$00,$00,$00
            fcb     $00,$00,$00,$00,$00,$00,$00,$f0
            fcb     $00,$00,$10,$00,$00,$00

sample.end:


zix		include	"Music/pop.asm"		; Popcorn tune
endzix		equ	*
