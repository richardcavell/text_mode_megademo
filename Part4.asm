* This is Part 4 of Text Mode Demo
* by Richard Cavell
* June - July 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This code is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by a number of other authors.
* You can see here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
*
* ASCII art of Dogbert in the first section is by Hayley (hjw)
* from https://www.asciiart.eu/comics/dilbert
* and modified by me
* ASCII art in the second section was made by Microsoft Copilot and
* modified by me
* Animation done by me
* The sound of the finger snap is by cori at Wikimedia Commons
* https://commons.wikimedia.org/wiki/File:Finger_clicks.ogg
* All of the speech was created by https://speechsynthesis.online/
* The voice is "Maisie"
*
* DEBUG_MODE means you press T to toggle frame-by-frame mode.
* In frame-by-frame mode, you press F to see the next frame.
* Also, you can make the lower right corner character cycle when
* the interrupt request service routine operates.

DEBUG_MODE      EQU     0

* Between each section, wait this number of frames

WAIT_PERIOD	EQU	25

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

        jsr     zero_dp_register
	jsr	install_irq_service_routine
	jsr	turn_off_disk_motor
        jsr     turn_6bit_audio_on

	jsr	decb_spoof		; First section
	jsr	dogbert_routine		; Second section
	jsr	dot_routine		; Third section

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

	ldx	IRQ_HANDLER		; Load the current vector into y
	stx	decb_irq_service_routine	; We will call it at the
						; end of our own handler

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine
					;  is installed

	bsr	switch_on_irq		; Switch interrupts back on

	rts

*************************
* Text buffer information
*************************

TEXTBUF         EQU     $400            ; We're not double-buffering
TEXTBUFSIZE     EQU     $200            ; so there's only one text screen
TEXTBUFEND      EQU     (TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE   EQU     32
TEXT_LINES      EQU     16

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

	inc     TEXTBUFEND-1

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

	clra
	sta	DSKREG		; Turn off disk motor
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

************
* DECB spoof
************

decb_spoof:
        jsr     clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames	; Ignore the result

        lda     #0
        ldb	#0
        ldx     #decb_spoof_text
        jsr     display_text_graphic

	ldx	#TEXTBUF + 6 * COLS_PER_LINE
	lda	#143		; A green box

_decb_spoof_colour:

	ldb	#5		; Number of frames for each colour

_decb_spoof_loop:
	pshs	a,b,x
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	puls	a,b,x
	bne	_skip_decb_spoof

	sta	,x

	pshs	a,b,x
        ldx     #scroller_decb_spoof    ; Add the scroll text at the bottom
        jsr     display_scroll_text     ; of the screen
	puls	a,b,x

	decb
	beq	_next_colour

	pshs	d			; Could just use A
	ldd	scroller_decb_spoof	; Check for scroller finish
	puls	d
	bmi	_decb_spoof_finished

	bra	_decb_spoof_loop

_decb_spoof_finished:
	clra
	rts

_next_colour:
	adda	#16
	cmpa	#15
	bne	_no_reset

	lda	#143		; Go back to a green box

_no_reset:
	bra	_decb_spoof_colour

_skip_decb_spoof:
	lda	#1
	rts

decb_spoof_text:

	FCV	"DISK EXTENDED COLOR BASIC 3.0",0
	FCV	"COPR. 1982, 1986, 2025 BY TANDY",0
	FCV	"UNDER LICENSE FROM MICROSOFT",0
	FCV	"AND MICROWARE SYSTEMS CORP.",0
	FCV	0
	FCV	"OK",0
	FCB	255

prompt_text:

	FCV	"WHAT DO YOU THINK OF THIS?",0
	FCB	255

scroller_decb_spoof:

        FDB     0       ; Starting frame
        FCB     0       ; Frame counter
        FCB     5       ; Frames to pause
        FDB     scroll_text_decb_spoof
        FDB     TEXTBUF+15*32

scroll_text_decb_spoof:

        FCV     "                                "
        FCV     "DECB SPOOF SCROLLER"
        FCV     " TESTING TESTING TESTING"
        FCV     "                                "
        FCB     0


*****************
* Dogbert Routine
*****************

dogbert_routine:

        jsr     clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames

        lda     #2
        ldb	#7
        ldx     #dogbert
        jsr     display_text_graphic

_loop:
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	_skip_dogbert

	ldd	dogbert_frames
	addd	#1
	std	dogbert_frames

	cmpd	#1000
	beq	_turn_dogbert

_dogbert_scroll:
        ldx     #scroller_dogbert       ; Add the scroll text at the bottom
        jsr     display_scroll_text     ; of the screen

	bra	_loop

        rts

_skip_dogbert:
	lda	#1
	rts

_turn_dogbert:
        jsr     clear_screen

        lda     #2
        ldb	#7
        ldx     #dogbert_2
        jsr     display_text_graphic

	bra	_dogbert_scroll

dogbert_frames:

	RZB	2

* These text graphics are by Hayley at asciiart.eu

dogbert:

	FCV	"     ,-\"\"\"\"-.",0
	FCV	"  ,-;-.      '.",0
	FCV	"  ! ! !--/ \\   \\",0
	FCV	"  '-'-' !   !  !",0
	FCV	"  (.)   !   !  !",0
	FCV	"  !      '-'   !",0
	FCV	"  !      ! !   !",0
	FCV	"   \\     (.)  /",0
	FCV	"    '-.    .-'",0
	FCV	"      ! !  !",0
	FCV	"HJW   ! !  !",0
	FCV	"     (.(...!",0
	FCB	255

dogbert_end:

dogbert_2:

	FCV	"   .-'\"\"\"'-.",0
	FCV	" .'  .-.-.  '.",0
	FCV	"/ !--! ! !--! \\",0
	FCV	"! !  '-'-'  ! !",0
	FCV	"\\./   (.)   \\./",0
	FCV	"!!           !!",0
	FCV	"\\.)         (./",0
	FCV	"  \".       .\"",0
	FCV	"    !  !  !",0
	FCV	"    !  !  !     HJW",0
	FCV	"   (...!...)",0
	FCB	255

dogbert_2_end:

**********************
* Display scroll text
*
* Inputs:
* X = scroll text data
*
* Outputs: None
**********************

display_scroll_text:

        ldd     ,x
        beq     _display_scroll_is_active
        bmi     _display_scroll_is_inactive

        subd    #1              ; Countdown to scrolltext start
        std     ,x
        rts

_display_scroll_is_inactive:
        rts

_display_scroll_is_active:
        lda     2,x
        beq     _display_scroll_needs_update

        deca
        sta     2,x
        rts

_display_scroll_needs_update:
        lda     3,x
        sta     2,x     ; Reset the frame counter

        ldy     4,x     ; Pointer to the text
        leay    1,y
        sty     4,x

        ldu     6,x     ; U is where on the screen to start
        lda     #COLS_PER_LINE  ; There are 32 columns per line

_display_scroll_text_loop_2:

        ldb     ,y+
        beq     _display_scroll_end
        stb     ,u+

        deca
        bne     _display_scroll_text_loop_2

        rts

_display_scroll_end:
        ldd     #-1
        std     ,x
        rts

scroller_dogbert:

        FDB     0       ; Starting frame
        FCB     0       ; Frame counter
        FCB     5       ; Frames to pause
        FDB     scroll_text_dogbert
        FDB     TEXTBUF+15*32

scroll_text_dogbert:

        FCV     "                                "
        FCV     "DOGBERT SCROLLER"
        FCV     " TESTING TESTING TESTING"
        FCV     "                                "
        FCB     0

******************
* Clear the screen
*
* Inputs: None
* Outputs: None
******************

GREEN_BOX       EQU     $60

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
        ldb     _debug_mode_toggle
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
        com     _debug_mode_toggle
        bra     _wait_for_vblank

_debug_mode_toggle:

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
	tsta
        puls    a
	bne	_wait_frames_skip

        deca
        bne     wait_frames

	clra
        rts

_wait_frames_skip:
	lda	#1
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

****************
* Dot mouth open
*
* Inputs: None
* Outputs: None
****************

dot_mouth_open:

	lda	#'O'
	ldx	#TEXTBUF + 2 * COLS_PER_LINE + 27
	sta	,x
	rts

*****************
* Dot mouth close
*
* Inputs: None
* Outputs: None
*****************

dot_mouth_close:

	lda	#'-' + 64
	ldx	#TEXTBUF + 2 * COLS_PER_LINE + 27
	sta	,x
	rts

************************
* Speech bubble
*
* Inputs:
* A = column to start in
* X = text
*
* Outputs: None
************************

speech_bubble:
	ldy	#TEXTBUF+3*COLS_PER_LINE
	leay	a,y

_speech_bubble_loop:
	lda	,x+
	beq	_speech_bubble_finished
	sta	,y+
	bra	_speech_bubble_loop

_speech_bubble_finished:
	rts

**************
* Create a dot
**************

dot_routine:

	jsr	clear_screen

	lda	#WAIT_PERIOD
	jsr	wait_frames
	tsta
	lbne	skip_dot

	clra
	ldb	#24
	ldx	#dot_graphic
	jsr	display_text_graphic
	bra	dot_start

; Made by Microsoft Copilot and modified by me, animated by me

dot_graphic:
	FCV	" /\\-/\\",0
	FCV	"( O.O )",0
	FCV	" > - <",0
	FCB	255

DOT_START	EQU	(TEXTBUF+9*COLS_PER_LINE+16)

dot_start:
        lda     #WAIT_PERIOD * 3
        jsr     wait_frames                     ; Wait a number of frames
	tsta
	bne	skip_dot

	ldx	#DOT_START	; in the middle of the screen

	lda	#'*' + 64	; Non-inverted asterisk
	sta	,x

	lda	#8
	ldx	#finger_snap_sound
	ldy	#finger_snap_sound_end
	jsr	play_sound

	lda	#WAIT_PERIOD*4		; Wait this number of frames
	lbsr	wait_frames
	tsta
	bne	skip_dot

	jsr	dot_mouth_open

	lda	#25
	ldx	#now_message
	jsr	speech_bubble

	lda	#8
	ldx	#now_sound
	ldy	#now_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

	lda	#WAIT_PERIOD		; Wait this number of frames
	jsr	wait_frames
	tsta
	bne	skip_dot

	jsr	dot_mouth_open

	lda	#25
	ldx	#move_message
	jsr	speech_bubble

	lda	#8
	ldx	#move_sound
	ldy	#move_sound_end
	jsr	play_sound
	jsr	dot_mouth_close

	lda	#WAIT_PERIOD		; Wait this number of frames
	jsr	wait_frames
	tsta
	bne	skip_dot

	jsr	dot_moves

skip_dot:
	jsr	clear_screen

        lda     #9
        ldb     #11
        ldx     #loading_message
        jsr     display_text_graphic

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

*********************************
* Draw 32
*
* Inputs:
* A = the symbol to be drawn
* B = the input angle
* X = the fulcrum screen position
*********************************

draw_32:
	sta	,x
	cmpb	#32
	blo	vertical
	cmpb	#64
	blo	backward_slash
	cmpb	#96
	blo	horizontal
	cmpb	#128
	blo	forward_slash
	cmpb	#160
	blo	vertical
	cmpb	#192
	blo	backward_slash
	cmpb	#228
	blo	horizontal
	bra	forward_slash

vertical:
	sta	-64,x
	sta	-32,x
	sta	,x
	sta	32,x
	sta	64,x
	rts

horizontal:
	sta	-2,x
	sta	-1,x
	sta	,x
	sta	1,x
	sta	2,x
	rts

backward_slash:
	sta	-66,x
	sta	-33,x
	sta	,x
	sta	33,x
	sta	66,x
	rts

forward_slash:
	sta	-62,x
	sta	-31,x
	sta	,x
	sta	31,x
	sta	62,x
	rts

***************
* The dot moves
***************

dot_moves:
	bra	move_dot

now_message:
	FCV	"\"NOW\""
	FCB	0

move_message:
	FCV	"\"MOVE\""
	FCB	0

move_more_message:
	FCV	"\"MOVE MORE\""
	FCB	0

change_message:
	FCV	"\"CHANGE\""
	FCB	0

dot_frames:
	RZB	2

horizontal_scale_factor:
	RZB	2		; Fixed point scale factor

vertical_scale_factor:
	RZB	2		; Fixed point scale factor

horizontal_angle:
	RZB	1		; 0-255 out of 256

vertical_angle:
	RZB	1		; 0-255 out of 256

horizontal_angular_speed:
	RZB	1

vertical_angular_speed:
	RZB	1

displacement:
	RZB	2		; The amount that the dot moves

rotation_speed:
	RZB	1

rotation_angle:
	RZB	1

move_dot:
	ldd	#1000
	std	horizontal_scale_factor
	lda	#1
	sta	horizontal_angular_speed

move_dot_loop:
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	lbne	skip_dot

	lda	phase
	cmpa	#9
	lbeq	skip_dot

	ldd	dot_frames		; Add 1 to dot_frames
	addd	#1
	std	dot_frames

	ldb	horizontal_angle
	addb	horizontal_angular_speed
	stb	horizontal_angle

	jsr	sin			; Get the sin of our angle
	ldx	horizontal_scale_factor	; X = scale factor, D is sine
	jsr	multiply_fixed_point	; multiply D by X (scale by sine)
	jsr	round_to_nearest	; Need to round D up or down
	tfr	a,b
	sex
	std	displacement		; This is the horizontal displacement

	ldb	vertical_angle
	addb	vertical_angular_speed
	stb	vertical_angle

	jsr	sin
	ldx	vertical_scale_factor
	jsr	multiply_fixed_point
	jsr	round_to_nearest
	tfr	a,b
	lda	#32
	jsr	b_signed_mul
	addd	displacement
	std	displacement

	lda	rotation_angle
	adda	rotation_speed
	sta	rotation_angle

	jsr	consider_phase
	jsr	clear_area
	jsr	draw_dot

	bra	move_dot_loop


phase:
	RZB	1		; 0 = Starting to move
				; 1 = Moving more
				; 2 = Moving even more
				; 3 = Changing to X
				; 4 = Changing to !
				; 5 = Changing to smiley
				; 6 = Changing to 3 asterisks
				; 7 = Changing to 5 asterisks
				; 8 = Spinning
				; 9 = Loading

consider_phase:
	lda	phase
	cmpa	#0
	beq	_phase_0
	cmpa	#1
	beq	_phase_1
	cmpa	#2
	lbeq	_phase_2
	cmpa	#3
	lbeq	_phase_3
	cmpa	#4
	lbeq	_phase_4
	cmpa	#5
	lbeq	_phase_5
	cmpa	#6
	lbeq	_phase_6
	cmpa	#7
	lbeq	_phase_7
	cmpa	#8
	lbeq	_phase_8
	cmpa	#9
	lbeq	_phase_9

	; Impossible to get here
	rts

_phase_0:
	ldd	dot_frames
	cmpd	#512
	bne	_phase_0_return

	jsr	dot_mouth_open

	lda	#20
	ldx	#move_more_message
	jsr	speech_bubble

	lda	#8
	ldx	#move_more_sound
	ldy	#move_more_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

	ldd	#0
	std	dot_frames
	lda	#1
	sta	phase
	ldd	#2000
	std	horizontal_scale_factor
	lda	#2
	sta	horizontal_angular_speed

_phase_0_return:
	rts

_phase_1:
	ldd	dot_frames
	cmpd	#200
	blo	_phase_1_return
	lda	horizontal_angle
	bne	_phase_1_return

	jsr	dot_mouth_open

	lda	#20
	ldx	#move_more_message
	jsr	speech_bubble

	lda	#7
	ldx	#move_more_sound
	ldy	#move_more_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

	lda	#2
	sta	phase
	ldd	#0
	std	dot_frames
	ldd	#2500
	std	horizontal_scale_factor
	lda	#3
	sta	horizontal_angular_speed
	lda	#2
	sta	vertical_angular_speed
	ldd	#1000
	std	vertical_scale_factor

_phase_1_return:
	rts

_phase_2:
	ldd	dot_frames
	cmpd	#150
	blo	_phase_2_return
	lda	horizontal_angle
	bne	_phase_2_return

	lda	#8
	jsr	change

	lda	#3
	sta	phase
	ldd	#0
	std	dot_frames
	lda	#4
	sta	horizontal_angular_speed

_phase_2_return:
	rts

_phase_3:
	ldd	dot_frames
	cmpd	#150
	blo	_phase_3_return
	lda	horizontal_angle
	bne	_phase_3_return

	lda	#7
	jsr	change

	lda	#4
	sta	phase
	lda	#5
	sta	horizontal_angular_speed
	ldd	#0
	std	dot_frames

_phase_3_return:
	rts

_phase_4:
	ldd	dot_frames
	cmpd	#150
	blo	_phase_4_return
	lda	horizontal_angle
	bne	_phase_4_return

	jsr	dot_mouth_open

	lda	#7
	jsr	change

	lda	#5
	sta	phase
	lda	#3
	sta	vertical_angular_speed
	lda	#6
	sta	horizontal_angular_speed
	ldd	#0
	std	dot_frames

_phase_4_return:
	rts

_phase_5:
	ldd	dot_frames
	cmpd	#150
	blo	_phase_5_return
	lda	horizontal_angle
	bne	_phase_5_return

	lda	#7
	jsr	change

	lda	#6
	sta	phase
	ldd	#0
	std	dot_frames
	lda	#7
	sta	horizontal_angular_speed

_phase_5_return:
	rts

_phase_6:
	ldd	dot_frames
	cmpd	#100
	blo	_phase_6_return
	lda	horizontal_angle
	bne	_phase_6_return

	lda	#7
	jsr	change

	lda	#7
	sta	phase
	ldd	#0
	std	dot_frames
	lda	#3
	sta	vertical_angular_speed
	lda	#5
	sta	horizontal_angular_speed

_phase_6_return:
	rts

_phase_7:
	ldd	dot_frames
	cmpd	#150
	blo	_phase_7_return

	lda	#7
	ldx	#finger_snap_sound
	ldy	#finger_snap_sound_end
	jsr	play_sound

	lda	#8
	sta	phase
	ldd	#0
	std	dot_frames
	lda	#1
	sta	vertical_angular_speed
	lda	#4
	sta	horizontal_angular_speed

	lda	#3
	sta	rotation_speed

_phase_7_return:
	rts

_phase_8:
	ldd	dot_frames
	cmpd	#194
	blo	_phase_8_return

	lda	#8
	ldx	#finger_snap_sound
	ldy	#finger_snap_sound_end
	jsr	play_sound

	lda	#9
	sta	phase

_phase_8_return:
	rts

_phase_9:
	rts

********
* Change
********

change:
	pshs	a
	jsr	dot_mouth_open

	lda	#23
	ldx	#change_message
	jsr	speech_bubble

	puls	a
	ldx	#change_sound
	ldy	#change_sound_end
	jsr	play_sound

	jsr	dot_mouth_close
	rts

**********
* Draw dot
**********

draw_dot:
	ldd	displacement
	ldx	#DOT_START
	leax	d,x

	lda	phase
	cmpa	#0
	beq	_draw_asterisk
	cmpa	#1
	beq	_draw_asterisk
	cmpa	#2
	beq	_draw_asterisk
	cmpa	#3
	beq	_draw_x
	cmpa	#4
	beq	_draw_bang
	cmpa	#5
	beq	_draw_smiley
	cmpa	#6
	beq	_draw_3_asterisks
	cmpa	#7
	beq	_draw_5_asterisks
	cmpa	#8
	beq	_draw_spinning
	cmpa	#9
	beq	_draw_loading

	; Should never get here
	rts

_draw_asterisk:
	lda	#'*' + 64
	sta	,x

	rts

_draw_x:
	lda	#'X'
	sta	,x

	rts

_draw_bang:
	lda	#'!' + 64
	sta	,x

	rts

_draw_smiley:
	lda	#':' + 64
	sta	-1,x
	lda	#'-' + 64
	sta	,x
	lda	#')' + 64
	sta	1,x

	rts

_draw_3_asterisks:
	lda	#'*' + 64
	sta	-32,x
	sta	,x
	sta	32,x

	rts

_draw_5_asterisks:
	lda	#'*' + 64
	sta	-64,x
	sta	-32,x
	sta	,x
	sta	32,x
	sta	64,x

	rts

_draw_spinning:
	lda	#'*' + 64
	ldb	rotation_angle

	jsr	draw_32
	rts

_draw_loading:
	lda	#9
	ldb	#11
	ldx	#loading_message
	jsr	display_text_graphic
	rts

loading_message:
	FCV	"LOADING..."
	FCB	0
	FCV	255

************
* Clear area
************

clear_area:
	ldx	#TEXTBUF+3*COLS_PER_LINE
	ldd	#GREEN_BOX << 8 | GREEN_BOX

clear_area_loop:
	std	,x++
	std	,x++
	std	,x++
	std	,x++
	cmpx	#TEXTBUFEND
	bne	clear_area_loop

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

*************************************
* Here is our raw data for our sounds
*************************************

finger_snap_sound:
	INCLUDEBIN "Sounds/Dot/Finger_Snap.raw"
finger_snap_sound_end:

now_sound:
	INCLUDEBIN "Sounds/Dot/Now.raw"
now_sound_end:

move_sound:
	INCLUDEBIN "Sounds/Dot/Move.raw"
move_sound_end:

move_more_sound:
	INCLUDEBIN "Sounds/Dot/Move_More.raw"
move_more_sound_end:

change_sound:
	INCLUDEBIN "Sounds/Dot/Change.raw"
change_sound_end:
