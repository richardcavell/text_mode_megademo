* This is Part 2 of Text Mode Demo
* by Richard Cavell
* June 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This code is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* ASCII art was made by an unknown person from
* https://www.asciiart.eu/animals/birds-land
* ASCII art made by Microsoft Copilot and modified by me
* ASCII art from Joan Stark, Normand Veilleux and Matzec, all from
* https://www.asciiart.eu/animals/birds-land
* All of the sounds in the dot routine were created by
* https://speechsynthesis.online/
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

***********************
* Output a bird graphic
***********************

	lda	#5
	ldb	#8
        ldx     #birds_graphic
	jsr	display_text_graphic

	bra	scroll_text

; This came from https://www.asciiart.eu/animals/birds-land
; Original artist unknown
; I have modified the graphic a little bit. All the animations are by me.

birds_graphic:

	FCV	"   ---     ---",0
	FCV	"  (O O)   (O O)",0
	FCV	" (  V  ) (  V  ) ",0
	FCV	"/--M-M- /--M-M-",0
	FCB	255

scroll_text:

	ldx	#bird_scrollers
	jsr	display_scroll_texts

	bra	create_dot

**************
* Create a dot
**************

create_dot:

	jsr	clear_screen

	lda	#WAIT_PERIOD
	jsr	wait_frames

	lda	#0
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

	ldx	#DOT_START	; in the middle of the screen

	lda	#'*'+64		; Non-inverted asterisk
	sta	,x

	lda	#8
	ldx	#finger_snap_sound
	ldy	#finger_snap_sound_end
	jsr	play_sound

******
* Wait
******

	lda	#WAIT_PERIOD*4		; Wait this number of frames
	lbsr	wait_frames

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
	lbsr	wait_frames

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
	lbsr	wait_frames

***************
* The dot moves
***************

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
	lbeq	dot_end

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

	jsr	dot_mouth_open

	lda	#23
	ldx	#change_message
	jsr	speech_bubble

	lda	#8
	ldx	#change_sound
	ldy	#change_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

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

	jsr	dot_mouth_open

	lda	#23
	ldx	#change_message
	jsr	speech_bubble

	lda	#7
	ldx	#change_sound
	ldy	#change_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

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

	lda	#23
	ldx	#change_message
	jsr	speech_bubble

	lda	#7
	ldx	#change_sound
	ldy	#change_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

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

	jsr	dot_mouth_open

	lda	#23
	ldx	#change_message
	jsr	speech_bubble

	lda	#7
	ldx	#change_sound
	ldy	#change_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

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

	jsr	dot_mouth_open

	lda	#23
	ldx	#change_message
	jsr	speech_bubble

	lda	#7
	ldx	#change_sound
	ldy	#change_sound_end
	jsr	play_sound

	jsr	dot_mouth_close

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
	cmpd	#200
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

**********
* Draw dot
**********

draw_dot:
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
	ldd	displacement
	ldx	#DOT_START
	leax	d,x

	lda	#'*' + 64
	sta	,x

	rts

_draw_x:
	ldd	displacement
	ldx	#DOT_START
	leax	d,x

	lda	#'X'
	sta	,x

	rts

_draw_bang:
	ldd	displacement
	ldx	#DOT_START
	leax	d,x

	lda	#'!' + 64
	sta	,x

	rts

_draw_smiley:
	ldd	displacement
	ldx	#DOT_START-1
	leax	d,x

	lda	#':' + 64
	sta	,x+
	lda	#'-' + 64
	sta	,x+
	lda	#')' + 64
	sta	,x

	rts

_draw_3_asterisks:
	ldd	displacement
	ldx	#DOT_START
	leax	d,x

	lda	#'*' + 64
	sta	-32,x
	sta	,x
	sta	32,x

	rts

_draw_5_asterisks:
	ldd	displacement
	ldx	#DOT_START
	leax	d,x

	lda	#'*' + 64
	sta	-64,x
	sta	-32,x
	sta	,x
	sta	32,x
	sta	64,x

	rts

_draw_spinning:
	ldd	displacement
	ldx	#DOT_START
	leax	d,x

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

; If any part of the dot routine has been skipped, we end up here
skip_dot:
	bsr	clear_screen

dot_end:

; End of part 2!
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

**********************
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

***********************
* Display scroll texts
*
* Inputs:
* X = List of scrollers
*
* Outputs: None
***********************

display_scroll_texts:

	pshs	x
	bsr	wait_for_vblank_and_check_for_skip
	puls	x
	tsta
	bne	_display_scroll_skip

	pshs	x
	bsr	_display_scroll_texts_all_scrollers
	bsr	bird_movements
	puls	x

	bra	display_scroll_texts

_display_scroll_skip:
	lda	#1
	rts

_display_scroll_texts_all_scrollers:

	tfr	x,y

_display_scroll_texts_loop:
	pshs	y
	ldx	,y
	beq	_display_scroll_texts_finished

	lbsr	display_scroll_text
	puls	y
	leay	2,y
	bra	_display_scroll_texts_loop

_display_scroll_texts_finished:
	puls	y	; Reset the stack

	rts

bird_scrollers:

	FDB	#scroller_0
	FDB	#scroller_1
	FDB	#scroller_2
	FDB	#scroller_3
	FDB	#scroller_4
	FDB	#scroller_9
	FDB	#scroller_10
	FDB	#scroller_11
	FDB	#scroller_12
	FDB	#scroller_13
	FDB	#scroller_14
	FDB	#scroller_15
	FDB	0

****************
* Bird movements
*
* Inputs: None
* Outputs: None
****************

bird_movement_frame_counter:

	FDB	0

bird_movements:
	ldd	bird_movement_frame_counter
	addd	#1
	std	bird_movement_frame_counter

	cmpd	#200
	beq	left_bird_blinks
	cmpd	#210
	beq	left_bird_unblinks

	cmpd	#500
	beq	right_bird_blinks
	cmpd	#510
	beq	right_bird_unblinks

	cmpd	#700
	beq	left_bird_foot_moves
	cmpd	#1300
	beq	left_bird_foot_unmoves

	cmpd	#980
	beq	right_bird_foot_moves
	cmpd	#1010
	beq	right_bird_foot_unmoves

	cmpd	#1400
	beq	left_bird_moves_wings
	cmpd	#1450
	beq	left_bird_unmoves_wings

	cmpd	#1500
	beq	reset_counter

	rts

left_bird_blinks:

	ldx	#TEXTBUF+6*COLS_PER_LINE+11
	lda	#'-' + 64
	sta	,x++
	sta	,x
	rts

left_bird_unblinks:

	ldx	#TEXTBUF+6*COLS_PER_LINE+11
	lda	#'O'
	sta	,x++
	sta	,x
	rts

right_bird_blinks:

	ldx	#TEXTBUF+6*COLS_PER_LINE+19
	lda	#'-' + 64
	sta	,x++
	sta	,x
	rts

right_bird_unblinks:

	ldx	#TEXTBUF+6*COLS_PER_LINE+19
	lda	#'O'
	sta	,x++
	sta	,x
	rts

left_bird_foot_moves:

	ldx	#TEXTBUF+8*COLS_PER_LINE+10
	lda	#'M'
	sta	,x+
	lda	#'-' + 64
	sta	,x
	rts

left_bird_foot_unmoves:

	ldx	#TEXTBUF+8*COLS_PER_LINE+10
	lda	#'-' + 64
	sta	,x+
	lda	#'M'
	sta	,x
	rts

right_bird_foot_moves:

	ldx	#TEXTBUF+8*COLS_PER_LINE+18
	lda	#'M'
	sta	,x+
	lda	#'-' + 64
	sta	,x
	rts

right_bird_foot_unmoves:

	ldx	#TEXTBUF+8*COLS_PER_LINE+18
	lda	#'-' + 64
	sta	,x+
	lda	#'M'
	sta	,x
	rts

left_bird_moves_wings:

	ldx	#TEXTBUF+7*COLS_PER_LINE+9
	lda	#'/' + 64
	sta	,x
	ldx	#TEXTBUF+7*COLS_PER_LINE+15
	lda	#'\\' + 64
	sta	,x
	rts

left_bird_unmoves_wings:

	ldx	#TEXTBUF+7*COLS_PER_LINE+9
	lda	#'(' + 64
	sta	,x
	ldx	#TEXTBUF+7*COLS_PER_LINE+15
	lda	#')' + 64
	sta	,x
	rts

reset_counter:

	ldd	#0
	std	bird_movement_frame_counter
	rts

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

***************
* Speech bubble
*
* Inputs:
* A = column to start in
* X = text
*
* Outputs: None
***************

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
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	FCV	"8                       \"\"\"\"\"                       8",0
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

cartman_graphic:
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
cartman_graphic_end:

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

scroller_14:

	FDB	100	; Starting frame
	FCB	0	; Frame counter
	FCB	8	; Frames to pause
	FDB	scroll_text_14
	FDB	TEXTBUF+14*32

scroll_text_14:

	FCV	"                                "
	FCV	"THIS IS ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_13:

	FDB	150	; Starting frame
	FCB	0	; Frame counter
	FCB	10	; Frames to pause
	FDB	scroll_text_13
	FDB	TEXTBUF+13*32

scroll_text_13:

	FCV	"                                "
	FCV	"THIS IS YET ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_12:

	FDB	200	; Starting frame
	FCB	0	; Frame counter
	FCB	12	; Frames to pause
	FDB	scroll_text_12
	FDB	TEXTBUF+12*32

scroll_text_12:

	FCV	"                                "
	FCV	"BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_11:

	FDB	250	; Starting frame
	FCB	0	; Frame counter
	FCB	15	; Frames to pause
	FDB	scroll_text_11
	FDB	TEXTBUF+11*32

scroll_text_11:

	FCV	"                                "
	FCV	"BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_10:

	FDB	300	; Starting frame
	FCB	0	; Frame counter
	FCB	20	; Frames to pause
	FDB	scroll_text_10
	FDB	TEXTBUF+10*32

scroll_text_10:

	FCV	"                                "
	FCV	"10BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_9:

	FDB	300	; Starting frame
	FCB	0	; Frame counter
	FCB	20	; Frames to pause
	FDB	scroll_text_9
	FDB	TEXTBUF+9*32

scroll_text_9:

	FCV	"                                "
	FCV	"9BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_0:

	FDB	300	; Starting frame
	FCB	0	; Frame counter
	FCB	20	; Frames to pause
	FDB	scroll_text_0
	FDB	TEXTBUF

scroll_text_0:

	FCV	"                                "
	FCV	"0BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_1:

	FDB	300	; Starting frame
	FCB	0	; Frame counter
	FCB	20	; Frames to pause
	FDB	scroll_text_1
	FDB	TEXTBUF+1*32

scroll_text_1:

	FCV	"                                "
	FCV	"1BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_2:

	FDB	300	; Starting frame
	FCB	0	; Frame counter
	FCB	20	; Frames to pause
	FDB	scroll_text_2
	FDB	TEXTBUF+2*32

scroll_text_2:

	FCV	"                                "
	FCV	"2BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_3:

	FDB	300	; Starting frame
	FCB	0	; Frame counter
	FCB	20	; Frames to pause
	FDB	scroll_text_3
	FDB	TEXTBUF+3*32

scroll_text_3:

	FCV	"                                "
	FCV	"3BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

scroller_4:

	FDB	300	; Starting frame
	FCB	0	; Frame counter
	FCB	20	; Frames to pause
	FDB	scroll_text_4
	FDB	TEXTBUF+4*32

scroll_text_4:

	FCV	"                                "
	FCV	"4BLAH BLAH BLAH ANOTHER TEST ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"TESTING ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	FCV	"                                "
	FCB	0

*************************************
* Here is our raw data for our sounds
*************************************

finger_snap_sound:
	INCLUDEBIN "Sounds/Finger_Snap/Finger_Snap.raw"
finger_snap_sound_end:

now_sound:
	INCLUDEBIN "Sounds/Dot_Sounds/Now.raw"
now_sound_end:

move_sound:
	INCLUDEBIN "Sounds/Dot_Sounds/Move.raw"
move_sound_end:

move_more_sound:
	INCLUDEBIN "Sounds/Dot_Sounds/Move_More.raw"
move_more_sound_end:

change_sound:
	INCLUDEBIN "Sounds/Dot_Sounds/Change.raw"
change_sound_end:
