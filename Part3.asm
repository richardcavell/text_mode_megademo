* This is Part 3 of Text Mode Demo
* by Richard Cavell
* June 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This code is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* ASCII art in the first section was made by Matzec from
* https://www.asciiart.eu/animals/birds-land
*
* DEBUG_MODE means you press T to toggle frame-by-frame mode.
* In frame-by-frame mode, you press F to see the next frame.
* Also, you can make the lower right corner character cycle when
* the interrupt request service routine operates.

DEBUG_MODE      EQU     1

* Between each section, wait this number of frames

WAIT_PERIOD	EQU	25

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

**********************
* Zero the DP register
**********************

        jsr     zero_dp_register

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

        jsr     turn_6bit_audio_on

*************************
* Text buffer information
*************************

TEXTBUF         EQU     $400            ; We're not double-buffering
TEXTBUFSIZE     EQU     $200            ; so there's only one text screen
TEXTBUFEND      EQU     (TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE   EQU     32
TEXT_LINES      EQU     16

******************
* Clear the screen
******************

	jsr	clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames                     ; Wait a number of frames

	bra	large_text_graphic_viewer_loop

***************************
* Large text graphic viewer
***************************
horizontal_coord:

	RZB	1

vertical_coord:

	RZB	1

large_text_graphic_viewer_loop:
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	skip_large_text_graphic_viewer

	lda	horizontal_coord
	ldb	vertical_coord
	ldx	#cartman_text_graphic
	ldy	#cartman_text_graphic_end
	jsr	large_text_graphic_display

	bra	large_text_graphic_viewer_loop

skip_large_text_graphic_viewer:

	jsr	clear_screen

; End of part 3!
end:
	jsr	uninstall_irq_service_routine

	rts

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

**********************
* Zero the DP register
**********************

zero_dp_register:

        clra
        tfr     a, dp

        rts

***************************
* Switch IRQ interrupts off
*
* Inputs: None
* Outputs: None
***************************

switch_off_irq:

	orcc	#0b00010000	; Switch off IRQ interrupts
	rts

**************************
* Switch IRQ interrupts on
*
* Inputs: None
* Outputs: None
**************************

switch_on_irq:

	andcc	#0b11101111	; Switch IRQ interrupts back on
	rts

*********************************
* Install our IRQ service routine
*
* Inputs: None
* Outputs: None
*********************************

IRQ_HANDLER	EQU	$10d

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off interrupts for now

	ldy	IRQ_HANDLER		; Load the current vector into y
	sty	decb_irq_service_routine	; We will call it at the
						; end of our own handler

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine
					;  is installed

	bsr	switch_on_irq		; Switch interrupts back on

	rts

***************************************************
* Our IRQ handler
*
* Make sure decb_irq_service_routine is initialized
***************************************************

irq_service_routine:

        lda     #1
        sta     vblank_happened

        lda     #DEBUG_MODE
        beq     _skip_debug_visual_indication

; For debugging, this provides a visual indication that
; our handler is running

;       inc     TEXTBUFEND-1

_skip_debug_visual_indication:
                ; In the interests of making our IRQ handler run fast,
                ; the routine assumes that decb_irq_service_routine
                ; has been correctly initialized

        jmp     [decb_irq_service_routine]

decb_irq_service_routine:

        RZB     2

*********************
* Turn off disk motor
*********************

DSKREG	EQU	$FF40

turn_off_disk_motor:

	clr	DSKREG		; Turn off disk motor
	rts

*********************
* Turn 6-bit audio on
*
* Inputs: None
* Outputs: None
*********************

AUDIO_PORT      EQU     $FF20           ; (the top 6 bits)
DDRA            EQU     $FF20
PIA2_CRA        EQU     $FF21
AUDIO_PORT_ON   EQU     $FF23           ; Port Enable Audio (bit 3)

turn_6bit_audio_on:

* This code was modified from code written by Trey Tomes

        lda     AUDIO_PORT_ON
        ora     #0b00001000
        sta     AUDIO_PORT_ON   ; Turn on 6-bit audio

* End code modified from code written by Trey Tomes

* This code was written by other people (see the top of this file)

        ldb     PIA2_CRA
        andb    #0b11111011
        stb     PIA2_CRA

        lda     #0b11111100
        sta     DDRA

        orb     #0b00000100
        stb     PIA2_CRA

* End of code written by other people

        rts

******************
* Clear the screen
*
* Inputs: None
* Outputs: None
******************

GREEN_BOX       EQU     ($60)

clear_screen:

        ldx     #TEXTBUF
        ldd     #GREEN_BOX << 8 | GREEN_BOX     ; Two green boxes

_clear_screen_loop:
        std     ,x++                    ; Might as well do 8 bytes at a time
        std     ,x++
        std     ,x++
        std     ,x++

        cmpx    #TEXTBUFEND             ; Finish in the lower-right corner
        bne     _clear_screen_loop
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

POLCAT          EQU     $A000

BREAK_KEY       EQU     3

vblank_happened:

        RZB     1

wait_for_vblank_and_check_for_skip:

        clr     vblank_happened

_wait_for_vblank_and_check_for_skip_loop:
        jsr     [POLCAT]
        cmpa    #' '                    ; Space bar
        beq     _wait_for_vblank_skip
        cmpa    #BREAK_KEY              ; Break key
        beq     _wait_for_vblank_skip
        ldb     #DEBUG_MODE
        beq     _wait_for_vblank
        cmpa    #'t'                    ; T key
        beq     _wait_for_vblank_invert_toggle
        cmpa    #'T'
        beq     _wait_for_vblank_invert_toggle
        ldb     debug_mode_toggle
        beq     _wait_for_vblank

; If toggle is on, require an F to go forward 1 frame

        cmpa    #'f'
        beq     _wait_for_vblank
        cmpa    #'F'
        beq     _wait_for_vblank
        bra     _wait_for_vblank_and_check_for_skip_loop

_wait_for_vblank:
        tst     vblank_happened
        beq     _wait_for_vblank_and_check_for_skip_loop

        clra            ; A VBlank happened
        rts

_wait_for_vblank_skip:
        lda     #1      ; User wants to skip
        rts

_wait_for_vblank_invert_toggle:
        com     debug_mode_toggle
        bra     _wait_for_vblank

debug_mode_toggle:

        RZB     1

*****************************
* Wait for a number of frames
*
* Inputs:
* A = number of frames
*****************************

wait_frames:
        pshs    a
        jsr     wait_for_vblank_and_check_for_skip
        puls    a

        deca
        bne     wait_frames

        rts

*****************************************
* Large text graphic display
*
* Inputs:
* A = horizontal coordinate
* B = vertical coordinate
* X = graphic data
* Y = end of graphic data
*****************************************

large_text_graphic_display:

	ldu	#TEXTBUF	; U = text buffer
	pshs	a,b
	lda	#0
	ldb	#0

_large_text_graphic_display_loop:

	bsr	output_char

	inca			; Next horizontal position
	cmpa	#COLS_PER_LINE
	blo	_large_text_graphic_display_loop

	clra			; Next line
	incb
	cmpb	#TEXT_LINES
	blo	_large_text_graphic_display_loop

	puls	a,b
	rts

output_char:
	lda	#'*' + 64
	sta	,u+
	rts

*************
* Output line
*************

**********************
* Display scroll text
*
* Inputs:
* X = scroll text data
*
* Outputs: None
**********************

display_scroll_text:

	ldd	,x
	beq	_display_scroll_is_active
	bmi	_display_scroll_is_inactive

	subd	#1		; Countdown to scrolltext start
	std	,x
	rts

_display_scroll_is_inactive:
	rts

_display_scroll_is_active:
	lda	2,x
	beq	_display_scroll_needs_update

	deca
	sta	2,x
	rts

_display_scroll_needs_update:
	lda	3,x
	sta	2,x	; Reset the frame counter

	ldy	4,x	; Pointer to the text
	leay	1,y
	sty	4,x

	ldu	6,x	; U is where on the screen to start
	lda	#COLS_PER_LINE	; There are 32 columns per line

_display_scroll_text_loop_2:

	ldb	,y+
	beq	_display_scroll_end
	stb	,u+

	deca
	bne	_display_scroll_text_loop_2

	rts

_display_scroll_end:
	ldd	#-1
	std	,x
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

*******************************
* Play a sound sample
*
* Inputs:
* A = The delay between samples
* X = The sound data
* Y = The end of the sound data
*******************************

play_sound:

        pshs    a,x,y
        bsr     switch_off_irq_and_firq
        puls    a,x,y

        pshs    y       ; _play_sound uses A, X and 2,S

        bsr     _play_sound

        puls    y

        bsr     switch_on_irq_and_firq

        rts

_play_sound:
        cmpx    2,s                     ; Compare X with Y

        bne     _play_sound_more        ; If we have no more samples, exit

        rts

_play_sound_more:
        ldb     ,x+
        stb     AUDIO_PORT

        tfr     a,b

_play_sound_delay_loop:
        tstb
        beq     _play_sound             ; Have we completed the delay?

        decb                            ; If not, then wait some more

        bra     _play_sound_delay_loop

************************
* Display a text graphic
*
* Inputs:
* A = Line number
* B = Column number
* X = Graphic data
************************

display_text_graphic:

        tfr     x,y     ; Y = graphic data

        tfr     d,u     ; Save B
        ldb     #COLS_PER_LINE
        mul
        ldx     #TEXTBUF
        leax    d,x
        tfr     u,d     ; B = column number
        leax    b,x     ; X = Screen memory to start at

_display_text_graphic_loop:
        lda     ,y+
        beq     _text_graphic_new_line
        cmpa    #255
        beq     _display_text_graphic_finished
        sta     ,x+
        bra     _display_text_graphic_loop

_text_graphic_new_line:
        tfr     d,u             ; Save register B
        tfr     x,d
        andb    #0b11100000
        addd    #COLS_PER_LINE
        tfr     d,x
        tfr     u,d             ; Get B back
        leax    b,x
        bra     _display_text_graphic_loop

_display_text_graphic_finished:
        rts

*************************************************************
* sine function
*
* Input:
* D = angle (unsigned) (256 is a complete circle)
* (just B is used)
*
* Output:
* D = sin of angle (signed double byte between -256 and +256)
*************************************************************

sin:
	clra			; Clamp it to 0-255
	ldx	#sin_table
	leax	d,x
	ldd	d,x		; Put sin_table + 2 * B into D

	rts

sin_table:
	INCLUDE "sin_table.asm"
sin_table_end:

*****************************
* Multiply fixed point signed
*
* Inputs:
* D = fixed point number, signed
* X = fixed point number, signed
*
* Outputs:
* D = result, signed
*****************************

result_sign:	RZB	1

multiply_fixed_point:
	clr	result_sign

	tsta			; Is D negative?
	bpl	D_is_positive

				; D is negative
	com	result_sign

	bsr	complement_d

D_is_positive:
	cmpx	#0		; Is X negative?
	bpl	X_is_positive

	com	result_sign	; If yes, then result switches sign

	pshs	d
	tfr	x,d
	bsr	complement_d	; And make it positive
	tfr	d,x
	puls	d

X_is_positive:
	bsr	multiply_fixed_point_unsigned

	tst	result_sign	; If the result should be negative
	beq	result_is_positive

	bsr	complement_d	; Then make it negative

result_is_positive:
	rts

complement_d:
	coma
	comb
	addd	#1
	cmpd	#$8000
	bne	no_overflow

	ldd	#$7fff		; Clamp at highest possible value

no_overflow:
	rts

**********************************
* Multiply fixed point unsigned
*
* Inputs:
* D = fixed point number, unsigned
* X = fixed point number, unsigned
*
* Outputs:
* D = result
**********************************

saved_d:
d_upper:
	RZB	1	; Save both operands
d_lower:
	RZB	1

saved_x:
x_upper:
	RZB	1
x_lower:
	RZB	1

result:
result_upper:
	RZB	1
result_lower:
	RZB	1

multiply_fixed_point_unsigned:
	std	saved_d		; Save D
	stx	saved_x		; Save X
	clra
	clrb
	std	result		; Result is 0

	lda	d_upper
	ldb	x_upper
	mul

	tsta			; If a is not clear,
	bne	overflow	; we have overflowed

	stb	result_upper

	lda	d_upper
	ldb	x_lower
	mul

	addd	result
	std	result

	lda	d_lower
	ldb	x_upper
	mul

	addd	result
	std	result

	lda	d_lower
	ldb	x_lower
	mul

	tfr	a,b			; We lose precision here
	clra
	addd	result
	std	result

	ldd	result			; Return value in D
	rts

overflow:
	ldd	#$ffff			; Return highest possible number
	rts

*************************************
* Round to nearest
*
* Input:
* D = fixed point number
*
* Output:
* D = that number, rounded to nearest
*************************************

round_to_nearest:
	tsta

	bmi	negative_d

	tstb
	bpl	no_adjust_a

	adda	#1			; Add 1 to whole part

	cmpa	#128			; Has it overflowed?
	bne	done_adjusting_a	; No, finish up

	lda	#127			; We have overflowed, so clamp
	ldb	#255			; to the largest number
	rts

negative_d:
	tstb
	bpl	round_to_neg_inf

	adda	#1

done_adjusting_a:
no_adjust_a:
round_to_neg_inf:
	clrb
	rts

**************
* B-signed mul
*
* Inputs:
* A (unsigned)
* B (signed)
**************

b_signed_mul:

	tstb
	bmi	_b_signed_is_negative

	mul
	rts

_b_signed_is_negative:
	negb
	mul
	coma
	comb
	addd	#1
	rts

***********************************
* Uninstall our IRQ service routine
*
* Inputs: None
* Outputs: None
***********************************

uninstall_irq_service_routine:

        jsr     switch_off_irq

        ldy     decb_irq_service_routine
        sty     IRQ_HANDLER

        jsr     switch_on_irq

        rts

**************
* Scroll texts
**************

scroller_15:

	FDB	0	; Starting frame
	FCB	0	; Frame counter
	FCB	5	; Frames to pause
	FDB	scroll_text_15
	FDB	TEXTBUF+15*32

scroll_text_15:

	FCV	"                                "
	FCV	"THIS IS A TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

***************
* Text graphics
***************

* Art by Joan Stark

face_graphic:
	FCV	"      ..-'''''-..",0
	FCV	"    .'  .     .  '.",0
	FCV	"   /   (.)   (.)   \\",0
	FCV	"  !  ,           ,  !",0
	FCV	"  !  \\`.       .`/  !",0
	FCV	"   \\  '.`'\"\"'\"`.'  /",0
	FCV	"    '.  `'---'`  .'",0
	FCV	"JGS   '-.......-'",0
	FCB	255

happy_face_graphic:

* Art by Joan Stark

	FCV	"      ..-'''''-..",0
	FCV	"    .'  .     .  '.",0
	FCV	"   /   (o)   (o)   \\",0
	FCV	"  !                 !",0
	FCV	"  !  \\           /  !",0
	FCV	"   \\  '.       .'  /",0
	FCV	"    '.  `'---'`  .'",0
	FCV	"JGS   '-.......-'",0
	FCB	255

* Art by Normand Veilleux

	FCV	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",0
	FCV	"8                                                   8",0
	FCV	"8  a---------------a                                8",0
	FCV	"8  !               !                                8",0
	FCV	"8  !               !                                8",0
	FCV	"8  !               !                               8\"",0
	FCV	"8  \"---------------\"                               8a",0
	FCV	"8                                                   8",0
	FCV	"8                                                   8",0
	FCV	"8                      ,aaaaa,                      8",0
	FCV	"8                    ad\":::::\"ba                    8",0
	FCV	"8                  ,d::;gPPRg;::b,                  8",0
	FCV	"8                  d::dP'   'Yb::b                  8",0
	FCV	"8                  8::8)     (8::8                  8",0
	FCV	"8                  Y;:Yb     dP:;P  O               8",0
	FCV	"8                  'Y;:\"8ggg8\":;P'                  8",0
	FCV	"8                    \"Yaa:::aaP\"                    8",0
	FCV	"8                       \"\"\"\"\"                       8",0
	FCV	"8                                                   8",0
	FCV	"8                       ,d\"b,                       8",0
	FCV	"8                       d:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                  aaa  'bad'  aaa                  8",0
	FCV	"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"' '\"\"\"\"\"\"\"\"\"' '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"",0
	FCV	"                                   Normand  Veilleux",0
	FCV	255

* Art by Matzec

cartman_text_graphic:
	FCV	"                       ..-**-..",0
	FCV	"                    .,(        ),.",0
	FCV	"                 .-\"   '-'----'   \"-.",0
	FCV	"              .-'                    '-.",0
	FCV	"            .'                          '.",0
	FCV	"          .'    ...--**'\"\"\"\"\"\"'**--...    '.\\",0
	FCV	"         /..-*\"'...--**'\"\"\"\"\"\"'**--...'\"*-..\\",0
	FCV	"        /...-*\"'   .-*\"*-.  .-*\"*-.   '\"*-...",0
	FCV	"       :          /       ;:       \\          ;",0
	FCV	"       :         :     *  !!  *     :         ;",0
	FCV	"        \        '.     .'  '.     .'        /",0
	FCV	"         \         '-.-'      '-.-'         /",0
	FCV	"      .-*''.                              .'-.",0
	FCV	"   .-'      '.                          .'    '.",0
	FCV	"  :           '-.        ....        .-'        '..",0
	FCV	" ;\"*-..          '-..  --... `   ..-'        ..*'  '*.",0
	FCV	":      '.            `\"*-....-*\"`           (        :",0
	FCV	" ;      ;                 *!                 '-.     ;",0
	FCV	"  '...*'                   !                    \"\"--'",0
	FCV	"   :                      *!                      :",0
	FCV	"   '.                      !                     .'",0
	FCV	"     '...                 *!        ....----...-'",0
	FCV	"      \  \"\"\"----.....------'-----\"\"\"         /",0
	FCV	"       \  ....-------...        .....---..  /",0
	FCV	"       :'\"              '-..--''          \"';",0
	FCV	"        '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"' '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"'",0
	FCV	"              C A R T M A N by Matzec",0
cartman_text_graphic_end:

*************************************
* Here is our raw data for our sounds
*************************************

