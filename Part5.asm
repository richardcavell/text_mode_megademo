* This is Part 5 of Text Mode Demo
* by Richard Cavell
* June - July 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This code is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM
*
* All of the ASCII art is from asciiart.eu
* Cartman is by Matzec, disk is by Normand Veilleux
* The Mortal Kombat art is by Blazej Kozlowski
* The rest are by anonymous/name unknown.
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

        jsr     zero_dp_register
	jsr	install_irq_service_routine
	jsr	turn_off_disk_motor
        jsr     turn_6bit_audio_on

	jsr	large_text_graphics		; First section
	jsr	credits				; Second section

	jsr	uninstall_irq_service_routine

	clra
	clrb
	rts		; Return to Disk Extended Color BASIC

*************************
* Text buffer information
*************************

TEXTBUF         EQU     $400            ; We're not double-buffering
TEXTBUFSIZE     EQU     $200            ; so there's only one text screen
TEXTBUFEND      EQU     (TEXTBUF+TEXTBUFSIZE)

COLS_PER_LINE   EQU     32
TEXT_LINES      EQU     16

***************************
* Large text graphic viewer
***************************

large_text_graphics:

	jsr	clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames                     ; Wait a number of frames

	bra	large_text_graphic_viewer_loop

graphic:
	RZB	1	; 0 = Cartman
			; 1 = Floppy disk
			; 2 = Earth
			; 3 = Red Dwarf
			; 4 = Mortal Kombat

horizontal_coord:	; of the graphic

	RZB	1

vertical_coord:		; of the graphic

	RZB	1

cartman_frames:
	RZB	2

cartman_horizontal_angle:
	RZB	1

cartman_vertical_angle:
	RZB	1

CARTMAN_TEXT_GRAPHIC_HEIGHT		EQU	27
DISK_TEXT_GRAPHIC_HEIGHT		EQU	28
EARTH_TEXT_GRAPHIC_HEIGHT		EQU	23
RED_DWARF_GRAPHIC_HEIGHT		EQU	23
MORTAL_KOMBAT_GRAPHIC_HEIGHT		EQU	35

CARTMAN_HORIZONTAL_ANGLE_SPEED		EQU	4
CARTMAN_VERTICAL_ANGLE_SPEED		EQU	2

CARTMAN_HORIZONTAL_SCALE		EQU	4200
CARTMAN_VERTICAL_SCALE			EQU	3000

CARTMAN_HORIZONTAL_DISPLACEMENT		EQU	-11
CARTMAN_VERTICAL_DISPLACEMENT		EQU	-6

large_text_graphic_viewer_loop:

	jsr	wait_for_vblank_and_check_for_skip
	tsta
	lbne	skip_large_text_graphic_viewer

	ldd	cartman_frames
	addd	#1
	std	cartman_frames

	cmpd	#250
	blo	_large_text_animate_cartman

	lda	cartman_horizontal_angle
	cmpa	#0
	bne	_large_text_animate_cartman

	lda	graphic
	cmpa	#0
	beq	_large_text_graphic_1
	cmpa	#1
	beq	_large_text_graphic_2
	cmpa	#2
	beq	_large_text_graphic_3
	cmpa	#3
	beq	_large_text_graphic_4
	jmp	skip_large_text_graphic_viewer

_large_text_graphic_1:
	lda	#1
	sta	graphic
	ldd	#0
	std	cartman_frames

	bra	_large_text_animate_cartman

_large_text_graphic_2:
	lda	#2
	sta	graphic
	ldd	#0
	std	cartman_frames
	bra	_large_text_animate_cartman

_large_text_graphic_3:
	lda	#3
	sta	graphic
	ldd	#0
	std	cartman_frames
	bra	_large_text_animate_cartman

_large_text_graphic_4:
	lda	#4
	sta	graphic
	ldd	#0
	std	cartman_frames
	bra	_large_text_animate_cartman

_large_text_animate_cartman:
	ldb	cartman_horizontal_angle
	addb	#CARTMAN_HORIZONTAL_ANGLE_SPEED
	stb	cartman_horizontal_angle

	jsr	sin			; Get the sine of our angle
	ldx	#CARTMAN_HORIZONTAL_SCALE
	jsr	multiply_fixed_point
	jsr	round_to_nearest
	adda	#CARTMAN_HORIZONTAL_DISPLACEMENT
	sta	horizontal_coord

	ldb	cartman_vertical_angle
	addb	#CARTMAN_VERTICAL_ANGLE_SPEED
	stb	cartman_vertical_angle

	jsr	sin
	ldx	#CARTMAN_VERTICAL_SCALE
	jsr	multiply_fixed_point
	jsr	round_to_nearest
	adda	#CARTMAN_VERTICAL_DISPLACEMENT
	sta	vertical_coord

	lda	graphic
	cmpa	#0
	beq	_cartman
	cmpa	#1
	beq	_floppy_disk
	cmpa	#2
	beq	_earth
	cmpa	#3
	beq	_red_dwarf
	cmpa	#4
	beq	_mortal_kombat

_cartman:
	ldx	#cartman_text_graphic
	ldy	#CARTMAN_TEXT_GRAPHIC_HEIGHT
	bra	_display_graphic

_floppy_disk:
	ldx	#disk_text_graphic
	ldy	#DISK_TEXT_GRAPHIC_HEIGHT
	bra	_display_graphic

_earth:
	ldx	#earth_text_graphic
	ldy	#EARTH_TEXT_GRAPHIC_HEIGHT
	bra	_display_graphic

_red_dwarf:
	ldx	#red_dwarf_graphic
	ldy	#RED_DWARF_GRAPHIC_HEIGHT
	bra	_display_graphic

_mortal_kombat:
	ldx	#mortal_kombat_graphic
	ldy	#MORTAL_KOMBAT_GRAPHIC_HEIGHT
	bra	_display_graphic

_display_graphic:
	lda	horizontal_coord
	ldb	vertical_coord
	jsr	large_text_graphic_display

	jmp	large_text_graphic_viewer_loop

skip_large_text_graphic_viewer:

	jsr	clear_screen

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

****************************************
* Wait for VBlank and check for skip
*
* Inputs: None
*
* Output:
* A = 0        -> a VBlank happened
* A = non-zero -> user is trying to skip
****************************************

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
*
* Outputs:
* None
*****************************

wait_frames:
        pshs    a
        jsr     wait_for_vblank_and_check_for_skip
	tsta
        puls    a
	bne	_wait_frames_skipped

        deca
        bne     wait_frames

	lda	#0
	rts

_wait_frames_skipped:
	lda	#1
        rts

*****************************************
* Large text graphic display
*
* Inputs:
*
* A = Horizontal coordinate
* B = Vertical coordinate
* X = Graphic data
* Y = Graphic height
*
* Outputs: None
*****************************************

large_text_horizontal_coordinate:
	RZB	1

large_text_vertical_coordinate:
	RZB	1

large_text_graphic_data:
	RZB	2

large_text_buffer:
	RZB	2

large_text_graphic_height:
	RZB	1

large_text_graphic_display:

	sta	large_text_horizontal_coordinate
	stb	large_text_vertical_coordinate
	stx	large_text_graphic_data
	ldx	#TEXTBUF
	stx	large_text_buffer
	tfr	y,d
	stb	large_text_graphic_height

	ldx	#TEXTBUF

	bsr	blank_lines_at_top
	jsr	skip_graphic_data_vertical

	bsr	do_lines

	bsr	blank_lines_at_bottom
	rts

**************************
* Blank lines at top
*
* Input:
* X = start of text buffer
*
* Output:
* X = where we are up to
**************************

blank_lines_at_top:

	lda	large_text_vertical_coordinate

_blank_lines_at_top_loop:
	cmpa	#0
	ble	_blank_lines_at_top_return

	pshs	a
	jsr	output_clear_line	; Input = X, Output = X
	puls	a

	deca
	bra	_blank_lines_at_top_loop

_blank_lines_at_top_return:		; Return X

	rts

************************
* Blank lines at bottom
*
* Input:
* X = where we are up to
*
* Output: None
************************

blank_lines_at_bottom:

_blank_lines_clear_loop:
	cmpx	#TEXTBUFEND
	beq	_blank_lines_none

	jsr	output_clear_line
	bra	_blank_lines_clear_loop

_blank_lines_none:
	rts

**********************************
* Do lines
*
* Input:
* X = where we are up to
*
* Output:
* X = where we are up to (updated)
**********************************

do_lines:
	lda	large_text_horizontal_coordinate

_do_lines_loop:
	cmpx	#TEXTBUFEND
	beq	_do_lines_done

	bsr	left_margin
	bsr	skip_graphic_data_horizontal
	bsr	print_text
	cmpx	#TEXTBUFEND
	beq	_do_lines_done

	jsr	right_margin

	bra	_do_lines_loop

_do_lines_done:

	rts

**********************************
* Left margin
*
* Inputs:
* X = where we are up to
*
* Outputs:
* X = where we are up to (updated)
**********************************

left_margin:

	lda	large_text_horizontal_coordinate

_left_margin_loop:
	cmpa	#0
	ble	_left_margin_none

	ldb	#GREEN_BOX
	stb	,x+
	deca
	bra	_left_margin_loop

_left_margin_none:		; Return X

	rts

**********************************
* Print text
*
* Inputs:
* X = where we are up to
*
* Outputs:
* A = right margin
* X = where we are up to (updated)
**********************************

print_text:
	lda	large_text_horizontal_coordinate
	cmpa	#0
	bpl	_print_text_start_at_zero

	lda	#0

_print_text_start_at_zero:
	ldy	large_text_graphic_data

_print_text_loop:
	ldb	,y+
	beq	_print_text_found_zero
	cmpb	#255
	beq	_found_255

_print_text_char:
	stb	,x+
	inca
	cmpa	#32
	beq	_print_text_finished
	bra	_print_text_loop

_print_text_finished:
	lda	,y+			; Find the zero
	bne	_print_text_finished
	sty	large_text_graphic_data	; Return A and X
	lda	#0
	rts

_print_text_found_zero:
	sty	large_text_graphic_data	; Return A and X
	pshs	a
	ldb	#32
	subb	,s+
	tfr	b,a
	rts


_found_255:
	lda	#GREEN_BOX

_255_loop:
	cmpx	#TEXTBUFEND
	beq	_255_finished
	sta	,x+
	bra	_255_loop

_255_finished:
	rts

****************************
* Skip graphic data vertical
*
* Input:
* X = start of text buffer
*
* Output:
* X = where we are up to
****************************

skip_graphic_data_vertical:

	lda	large_text_vertical_coordinate
	bpl	_skip_graphic_data_return

	ldy	large_text_graphic_data
_skip_graphic_loop:
	tst	,y+
	bne	_skip_graphic_loop
	inca
	bne	_skip_graphic_loop

	sty	large_text_graphic_data

_skip_graphic_data_return:
	rts

******************************
* Skip graphic data horizontal
*
* Input:
* X = start of text buffer
*
* Output:
* X = where we are up to
******************************

skip_graphic_data_horizontal:

	lda	large_text_horizontal_coordinate

	ldy	large_text_graphic_data

_skip_graphic_horizontal_loop:
	tsta
	bpl	_skip_graphic_data_horizontal_return

	ldb	,y+
	beq	_skip_graphic_data_hit_zero
	cmpb	#255
	bne	_skip_graphic_data_not_end

	leay	-1,y
	rts

_skip_graphic_data_not_end:
	inca
	bra	_skip_graphic_horizontal_loop

_skip_graphic_data_hit_zero:
	leay	-1,y

_skip_graphic_data_horizontal_return:
	sty	large_text_graphic_data
	rts				; Return X


************************
* Right margin
*
* Inputs:
* A = size of right margin
* X = where we are up to
*
* Outputs:
* X = where we are up to
************************

right_margin:

_right_margin_loop:
	tsta
	beq	_right_margin_finished
	ldb	#GREEN_BOX
	stb	,x+
	deca
	bra	_right_margin_loop

_right_margin_finished:		; Return X
	rts

*******************************
* Output clear line
*
* Inputs:
* X = start of text buffer line
*
* Outputs:
* X = start of the next line
*******************************

output_clear_line:

	lda	#GREEN_BOX
	ldb	#8

_output_clear_line_loop:
	sta	,x+
	sta	,x+
	sta	,x+
	sta	,x+

	decb
	bne	_output_clear_line_loop

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

*********
* Credits
*********

credits:

	ldu	#credit_roll

_credits_loop:
	pshs	u

	jsr	wait_for_vblank_and_check_for_skip
	puls	u
	tsta
	bne	_user_skip

	pshs	u
	jsr	clear_screen
	puls	u

	pshs	u
	bsr	draw_credits
	puls	u

	pshs	u
	lda	#WAIT_PERIOD
	jsr	wait_frames
	puls	u
	tsta
	bne	_user_skip

_find_next_line:			; Set U to point to the next line
	lda	,u+
	bne	_find_next_line

	bra	_credits_loop

_user_skip:
	lda	#1
	rts

*************

draw_credits:

	ldx	#TEXTBUF

_print_line:
	lda	,u+
	beq	_credits_next_line
	cmpa	#255
	beq	_credits_finished
	sta	,x+
	bra	_print_line

_credits_next_line:

	tfr	x,d
	addd	#32
	andb	#0b11100000
	tfr	d,x

	cmpx	#TEXTBUFEND
	blo	_print_line

	rts			; Screen has been filled

_credits_finished:

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

* Art by Matzec, modified by me

cartman_text_graphic:

	FCV	"                       ..-**-..",0
	FCV	"                    .,(        ),.",0
	FCV	"                 .-\"   '-'----'   \"-.",0
	FCV	"              .-'                    '-.",0
	FCV	"            .'                          '.",0
	FCV	"          .'    ...--**'\"\"\"\"\"\"'**--...    '.",0
	FCV	"         /..-*\"'...--**'\"\"\"\"\"\"'**--...'\"*-..\\",0
	FCV	"        /...-*\"'   .-*\"*-.  .-*\"*-.   '\"*-...\\",0
	FCV	"       :          /       ;:       \\          ;",0
	FCV	"       :         :     *  !!  *     :         ;",0
	FCV	"        \        '.     .'  '.     .'        /",0
	FCV	"         \         '-.-'      '-.-'         /",0
	FCV	"      .-*''.                              .'-.",0
	FCV	"   .-'      '.                          .'    '.",0
	FCV	"  :           '-.        ....        .-'        '..",0
	FCV	" ;\"*-..          '-..  --... '   ..-'        ..*'  '*.",0
	FCV	":      '.            '\"*-....-*\"'           (        :",0
	FCV	" ;      ;                 *!                 '-.     ;",0
	FCV	"  '...*'                   !                    \"\"--'",0
	FCV	"   :                      *!                      :",0
	FCV	"   '.                      !                     .'",0
	FCV	"     '...                 *!        ....----...-'",0
	FCV	"      \  \"\"\"----.....------'-----\"\"\"         /",0
	FCV	"       \  ....-------...        .....---..  /",0
	FCV	"       :'\"              '-..--''          \"';",0
	FCV	"        '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"' '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"'",0
	FCV	"              C A R T M A N BY MATZEC",0
	FCB	255

cartman_text_graphic_end:

* Art by Normand Veilleux, modified by me

disk_text_graphic:

	FCV	"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",0
	FCV	"8                                                   8",0
	FCV	"8  A---------------A                                8",0
	FCV	"8  !               !                                8",0
	FCV	"8  !               !                                8",0
	FCV	"8  !               !                               8\"",0
	FCV	"8  \"---------------\"                               8A",0
	FCV	"8                                                   8",0
	FCV	"8                                                   8",0
	FCV	"8                      ,AAAAA,                      8",0
	FCV	"8                    AD\":::::\"BA                    8",0
	FCV	"8                  ,D::;GPPRG;::B,                  8",0
	FCV	"8                  D::DP'   'YB::B                  8",0
	FCV	"8                  8::8)     (8::8                  8",0
	FCV	"8                  Y;:YB     DP:;P  O               8",0
	FCV	"8                  'Y;:\"8GGG8\":;P'                  8",0
	FCV	"8                    \"YAA:::AAP\"                    8",0
	FCV	"8                       \"\"\"\"\"                       8",0
	FCV	"8                                                   8",0
	FCV	"8                       ,D\"B,                       8",0
	FCV	"8                       B:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                       8:::8                       8",0
	FCV	"8                  AAA  'BAD'  AAA                  8",0
	FCV	"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"' '\"\"\"\"\"\"\"\"\"' '\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"",0
	FCV	"                                   NORMAND  VEILLEUX",0
	FCB	255

disk_text_graphic_end:

* Art by anonymous at asciiart.eu/space/planets
* Modified by me

earth_text_graphic:

	FCV	"              .-O#&&*''''?D:>B\\.",0
	FCV	"          .O/\"'''  '',, DMF9MMMMMHO.",0
	FCV	"       .O&#'        '\"MBHMMMMMMMMMMMHO.",0
	FCV	"     .O\"\" '         VODM*$&&HMMMMMMMMMM?.",0
	FCV	"    ,'              $M&OOD,-''(&##MMMMMMH\\",0
	FCV	"   /               ,MMMMMMM#B?#BOBMMMMHMMML",0
	FCV	"  &              ?MMMMMMMMMMMMMMMMM7MMM$R*HK",0
	FCV	" ?$.            :MMMMMMMMMMMMMMMMMMM/HMMMI'*L",0
	FCV	"1               IMMMMMMMMMMMMMMMMMMMMBMH'   T,",0
	FCV	"$H#:            '*MMMMMMMMMMMMMMMMMMMMB#)'  '?",0
	FCV	"]MMH#             \"\"*\"\"\"\"*#MMMMMMMMMMMMM'    -",0
	FCV	"MMMMMB.                   IMMMMMMMMMMMP'     :",0
	FCV	"HMMMMMMMHO                 'MMMMMMMMMT       .",0
	FCV	"?MMMMMMMMP                  9MMMMMMMM)       -",0
	FCV	"-?MMMMMMM                  IMMMMMMMMM?,D-    '",0
	FCV	" :IMMMMMM-                 'MMMMMMMT .MI.   :",0
	FCV	"  .9MMM[                    &MMMMM*' ''    .",0
	FCV	"   :9MMK                    'MMM#\"        -",0
	FCV	"     &M)                     '          .-",0
	FCV	"      '&.                             .",0
	FCV	"        '-,   .                     ./",0
	FCV	"            . .                  .-",0
	FCV	"              ''--..,DD###PP=\"\"'",0
	FCB	255

earth_text_graphic_end:

* Art by name unknown at asciiart.eu
* Modified by me

red_dwarf_graphic:

	FCV	"       ..                                   ,--------.",0
	FCV	"      / /                                 ,' /.!    /",0
	FCV	"    RED'                                ,'    !!   /",0
	FCV	"   DWARF                                \     !!  /",0
	FCV	"  / /                                    \.....---.  .---.",0
	FCV	"  ''                                .-----     ---:,'   / \\",0
	FCV	"                   ..-------..    ,'           ---:     ! !",0
	FCV	"    .-------.    ,'   !    :  '. /   ..-----------''.   \\ /",0
	FCV	"  ,:.     ;  '._/     ! .  :  ..\\----         ;   !..----'",0
	FCV	" //  ---.. ;   \\=   '---'..:     ! STARBUG  1  ;    :  \\",0
	FCV	"! '------' ;    !=               !.....        ;    :...!",0
	FCV	"!     ::   ;    !=........            :        ;    :   !",0
	FCV	"'.    ::   ;### !=       :       !    :        ;        !",0
	FCV	" \\)       ;    /=        :      !     :.. .---.         !",0
	FCV	"  '. 0  .--. ,'-\ :=====;:      /        /     \\       .!",0
	FCV	"    ---/    \\    '.'....!:    ,:        !       !    ,'/",0
	FCV	"       \\.--./      '---...---'  \\        \\.---./    / /",0
	FCV	"        \\,./                     '.    :::\\   /    /,'",0
	FCV	"         ! !                       '-..   !   ! ,.-'",0
	FCV	"         !!:                           ---(  !'-",0
	FCV	"         !!:                               ! !",0
	FCV	"         !!'                               ! !",0
	FCV	"       '\"---\"'                           '\"---\"'",0
	FCB	255

red_dwarf_graphic_end:

* This art is by Blazej Kozlowski at asciiart.eu
* I have modified it

mortal_kombat_graphic:

	FCV	"                       ...GGGGGPPPPP...",0
	FCV	"                  ..GD$$$$$$$$$$$$$$$$$$BP..",0
	FCV	"               .G$$$$$$P^^\"\"J$$B\"\"\"\"^^T$$$$$$P.",0
	FCV	"            .G$$$P^T$$B    D$P T;       \"\"^^T$$$P.",0
	FCV	"          .D$$P^\"  :$; '  :$;                \"^T$$B.",0
	FCV	"        .D$$P'      T$B.   T$B                  'T$$B.",0
	FCV	"       D$$P'      .GG$$$$BPD$$$P.D$BPP.           'T$$B",0
	FCV	"      D$$P      .D$$$$$$$$$$$$$$$$$$$$BP.           T$$B",0
	FCV	"     D$$P      D$$$$$$$$$$$$$$$$$$$$$$$$$B.          T$$B",0
	FCV	"    D$$P      D$$$$$$$$$$$$$$$$$$P^^T$$$$P            T$$B",0
	FCV	"   D$$P    '-'T$$$$$$$$$$$$$$$$$$BGGPD$$$$B.           T$$B",0
 	FCV	"  :$$$      .D$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P...G.     $$$;",0
	FCV	"  $$$;     D$$$$$$$$$$$$$$$$$$$$$$$P^\"^T$$$$P^^T$$$;    :$$$",0
	FCV	" :$$$     :$$$$$$$$$$$$$$:$$$$$$$$$.    \"^T$BPD$$$$,     $$$;",0
	FCV	" $$$;     :$$$$$$$$$$$$$$BT$$$$$P^^T$P.    'T$$$$$$;     :$$$",0
	FCV	":$$$      :$$$$$$$$$$$$$$P '^^^'    \"^T$P.    LB'TP       $$$;",0
	FCV	":$$$      $$$$$$$$$$$$$$$              'T$$P..;$B         $$$;",0
	FCV	"$$$;      $$$$$$$$$$$$$$;                'T$$$$:TB        :$$$",0
	FCV	"$$$;      $$$$$$$$$$$$$$$                        TB    .  :$$$",0
	FCV	":$$$     D$$$$$$$$$$$$$$$.                        $B...TB $$$;",0
	FCV	":$$$  .G$$$$$$$$$$$$$$$$$$$P............GP..      :$'^^^' $$$;",0
	FCV	" $$$;  '^^'T$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$P.    TB.., :$$$",0
	FCV	" :$$$       T$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$B.   \"^\"  $$$;",0
	FCV	"  $$$;       '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$B      :$$$",0
	FCV	"  :$$$        $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$;     $$$;",0
	FCV	"   T$$B    .  :$$'$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$;   D$$P",0
	FCV	"    T$$B   T$G$$; :$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$  D$$P",0
	FCV	"     T$$B   '^^'  :$$ \"^T$$$$$$$$$$$$$$$$$$$$$$$$$$$ D$$P",0
	FCV	"      T$$B        $P     T$$$$$$$$$$$$$$$$$$$$$$$$$;D$$P",0
	FCV	"       T$$B.      '       $$$$$$$$$$$$$$$$$$$$$$$$$$$$P",0
	FCV	"        'T$$$P.   BUG    D$$$$$$$$$$$$$$$$$$$$$$$$$$P'",0
	FCV	"          'T$$$$P......G$$$$$$$$$$$$$$$$$$$$$$$$$$P'",0
	FCV	"            \"^$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$^\"",0
	FCV	"               \"^T$$$$$$$$$$$$$$$$$$$$$$$$$$P^\"",0
	FCV	"                   \"\"\"^^^T$$$$$$$$$$P^^^\"\"\"",0

mortal_kombat_graphic_end:

credit_roll:

	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCV	"            CREDITS",0
	FCB	0
	FCB	0
	FCV	"  TESTING TESTING TESTING ",0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0
	FCB	0

	FCB	255		; Marks the end
