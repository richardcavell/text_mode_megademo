* This is Part 2 of Text Mode Demo
* by Richard Cavell
* June 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* This code is intended to run on a TRS-80 Color Computer 1,2 or 3
* with at least 32K of RAM

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

* DEBUG_MODE means you press T to toggle frame-by-frame mode.
* In frame-by-frame mode, you press F to see the next frame

DEBUG_MODE	EQU	0

		ORG $1800

*************************
* Install our IRQ handler
*************************

	lbsr	install_irq_service_routine

*************************
* Turn off the disk motor
*************************

	lbsr	turn_off_disk_motor

******************
* Clear the screen
******************

	lbsr	clear_screen

**************
* Create a dot
**************

TEXTBUF		EQU	$400		; We're not double-buffering
TEXTBUFSIZE	EQU	$200		; so there's only one text screen

DOT_START	EQU	(TEXTBUF+8*32+16)

	ldx	#DOT_START	; in the middle of the screen

	lda	#'*'+64		; Non-inverted asterisk
	sta	,x

******
* Wait
******
	ldb	#50		; Wait this number of frames

	leay	dot_graphic,PCR

	ldx	#TEXTBUF+24

display_graphic:
	lda	,y+
	beq	new_line
	cmpa	#255
	beq	dot_wait
	sta	,x+
	bra	display_graphic

new_line:
	tfr	x,d
	andb	#0b11100000
	addd	#32+24
	tfr	d,x
	bra	display_graphic

dot_wait:
	pshs	b
	jsr	check_for_space
	puls	b		; Doesn't affect condition codes
	tsta
	lbne	skip_dot

	pshs	b
	lbsr	wait_for_vblank
	puls	b
	decb
	bne	dot_wait

***************
* The dot moves
***************

	bra	move_dot

; Made by Microsoft Copilot and modified by me

dot_graphic:
	FCV	" /\\-/\\",0
	FCV	"( O.O )",0
	FCV	" > ' <",0
	FCB	255

dot_frames:
	RZB	2
phase:
	RZB	1		; 0 = Starting to move
				; 1 = Changing to X
				; 2 = Changing to :-)
				; 3 = Changing to !
				; 4 = Changing back to *
scale_factor:
	RZB	2		; Fixed point scale factor
angle:
	RZB	1		; 0-255 out of 256
dot_previous:
	RZB	2		; Previously drawn location of dot
displacement:
	RZB	1		; The amount that the dot moves
new_position:
	RZB	2		; The calculated new position

move_dot:
	clra			; A is really don't care
	ldb	angle		; D is our angle in fixed point
	lbsr	sin		; D is now the sine of our angle

	ldx	scale_factor		; X = scale factor, D is sine
	lbsr	multiply_fixed_point	; multiply D by X (scale by sine)
	lbsr	round_to_nearest	; Need to round D up or down
	sta	displacement		; This is the displacement

	lbsr	check_for_space
	tsta
	lbne	skip_dot

	lbsr	wait_for_vblank

	ldd	dot_frames		; Add 1 to dot_frames
	addd	#1
	std	dot_frames

	lda	phase			; If we're in phase 0...
	bne	not_phase_0

; Phase 0
	ldd	dot_frames
	cmpd	#150
	lblo	abort_phase_change
	ldd	scale_factor
	cmpd	#2000			; once we're at full speed...
	blo	abort_phase_change
	lda	angle			; and angle is 0...
	bne	abort_phase_change

	lda	#1			; ...go to phase 1
	sta	phase
	clra
	clrb
	std	dot_frames		; And start counting frames from 0

	bra	abort_phase_change

not_phase_0:
	lda	phase
	cmpa	#1
	bne	not_phase_1

	ldd	dot_frames
	cmpd	#50			; After 50 frames,...
	bne	abort_phase_change

	lda	#2
	sta	phase			; ...go to phase 2
	clra
	clrb
	std	dot_frames

not_phase_1:
	lda	phase
	cmpa	#2
	bne	not_phase_2

	ldd	dot_frames
	cmpd	#50			; After 50 frames...
	bne	abort_phase_change

	lda	#3
	sta	phase			; ...go to phase 3
	clra
	clrb
	std	dot_frames

not_phase_2:
	lda	phase
	cmpa	#3
	bne	not_phase_3

	ldd	dot_frames
	cmpd	#50
	bne	abort_phase_change

	lda	#4
	sta	phase
	clra
	clrb
	std	dot_frames

not_phase_3:
	lda	phase
	cmpa	#4
	lbne	dot_expands

	ldd	dot_frames
	cmpd	#50
	bne	abort_phase_change

	lda	#5
	sta	phase
	clra
	clrb
	std	dot_frames

abort_phase_change:
	lda	#$60		; Green box
	ldx	dot_previous
	sta	,x		; Erase previous dot
	sta	-1,x
	sta	1,x

	lda	displacement
	ldx	#DOT_START
	leax	a,x		; X is now the position of the new dot

	lda	phase
	bne	_test_for_1

	lda	#'*' + 64	; In phase 0, draw *
	sta	,x
	bra	phase_finished

_test_for_1:
	lda	phase
	cmpa	#1
	bne	_test_for_2

	lda	#'X'		; In phase 1, change to an X
	sta	,x

	bra	phase_finished

_test_for_2:
	lda	phase
	cmpa	#2
	bne	_test_for_3
	lda	#':' + 64
	sta	-1,x
	lda	#'-' + 64
	sta	,x
	lda	#')' + 64
	sta	1,x
	bra	phase_finished

_test_for_3:
	lda	phase
	cmpa	#3
	bne	_test_for_4
	lda	#'!' + 64
	sta	,x
	bra	phase_finished

_test_for_4:
	lda	phase
	cmpa	#4
	bne	dot_expands
	lda	#'*' + 64
	sta	,x
	bra	phase_finished

phase_finished:
	stx	dot_previous	; And erase after next VBlank

	ldd	scale_factor	; Increase the scale factor
	addd	#20		; gradually

	cmpd	#2000		; If D is over 2000,
	blt	d_is_clamped

	ldd	#2000		; Make it equal to 2000

d_is_clamped:
	std	scale_factor

	lda	angle		; (A fixed-point fraction)
	adda	#2		; It rotates constantly
	sta	angle

	lbra	move_dot

dot_expands:
	clr	phase
				; Phase 0 is 3-asterisks
				; Phase 1 is 5-asterisks
				; Phase 2 is 5 spinning
				; Phase 3 is up and down too

expand_dot:
	clra			; A is really don't care
	ldb	angle		; D is our angle in fixed point
	lbsr	sin		; D is now the sine of our angle

	ldx	scale_factor		; X = scale factor, D is sine
	lbsr	multiply_fixed_point	; multiply D by X (scale by sine)
	lbsr	round_to_nearest	; Need to round D up or down
	sta	displacement		; This is the displacement

	lbsr	check_for_space
	tsta
	lbne	skip_dot

	lbsr	wait_for_vblank

	ldd	dot_frames		; Add 1 to dot_frames
	addd	#1
	std	dot_frames

	lda	phase			; If we're in phase 0...
	bne	not_phase_0_expands

; Phase 0
	ldd	dot_frames
	cmpd	#50
	blo	abort_phase_change_expands

	lda	#1			; ...go to phase 1
	sta	phase
	clra
	clrb
	std	dot_frames		; and restart the framecount

	bra	abort_phase_change_expands

not_phase_0_expands:
	lda	phase
	cmpa	#1
	bne	not_phase_1_expands

	ldd	dot_frames
	cmpd	#50			; After 50 frames,...
	bne	abort_phase_change_expands

	lda	#2
	sta	phase			; ...go to phase 2
	clra
	clrb
	std	dot_frames

not_phase_1_expands:
	lda	phase
	cmpa	#2
	bne	not_phase_2_expands

	ldd	dot_frames
	cmpd	#200			; After 50 frames...
	bne	abort_phase_change_expands

	lda	#3
	sta	phase			; ...go to phase 3
	clra
	clrb
	std	dot_frames

not_phase_2_expands:
	lda	phase
	cmpa	#3
	bne	not_phase_3_expands

	ldd	dot_frames
	cmpd	#50
	bne	abort_phase_change_expands

	lda	#4
	sta	phase
	clra
	clrb
	std	dot_frames

not_phase_3_expands:
	lda	phase
	cmpa	#4
	lbne	dot_expands

	ldd	dot_frames
	cmpd	#50
	bne	abort_phase_change_expands

	lda	#5
	sta	phase
	clra
	clrb
	std	dot_frames

abort_phase_change_expands:
	lda	displacement
	ldx	#DOT_START
	leax	a,x		; X is now the position of the new dot

	pshs	x
	lbsr	clear_area
	puls	x

	lda	phase
	bne	_test_for_1_expands

	lda	#'*' + 64	; In phase 0, draw *
	sta	,x
	sta	-32,x
	sta	32,x
	bra	phase_finished_expands

_test_for_1_expands:
	lda	phase
	cmpa	#1
	bne	_test_for_2_expands

	lda	#'*' + 64	; In phase 1
	sta	-64,x
	sta	-32,x
	sta	,x
	sta	32,x
	sta	64,x

	bra	phase_finished_expands

internal_angle:
	RZB	1

_test_for_2_expands:
	lda	internal_angle
	adda	#2
	sta	internal_angle

	lda	phase
	cmpa	#2
	bne	_test_for_3_expands

	lda	#'*' + 64
	ldb	internal_angle
	lbsr	draw_32

	bra	phase_finished_expands

_test_for_3_expands:
	lda	phase
	cmpa	#3
	bne	_test_for_4_expands
	lda	#'*' + 64
	sta	,x
	bra	phase_finished_expands

_test_for_4_expands:
	lda	phase
	cmpa	#4
	bne	skip_dot
	lda	#'*' + 64
	sta	,x
	bra	phase_finished_expands

phase_finished_expands:
	stx	dot_previous	; And erase after next VBlank

	lda	angle		; (A fixed-point fraction)
	adda	#2		; It rotates constantly
	sta	angle

	lbra	expand_dot

; If any part of the dot routine has been skipped, we end up here
skip_dot:
	bsr	clear_screen

end:
	bsr	uninstall_irq_service_routine
	rts

*****************************************************************************
*	Subroutines
*****************************************************************************

* Assume that no registers are preserved

*********************************
* Switch IRQ interrupts on or off
*********************************

switch_off_irq:

	orcc	#0b00010000	; Switch off IRQ interrupts
	rts

switch_on_irq:

	andcc	#0b11101111	; Switch IRQ interrupts back on
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

*********************************
* Install our IRQ service routine
*********************************

IRQ_HANDLER	EQU	$10d

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off interrupts for now

	ldy	IRQ_HANDLER			; Load the current vector into y
	sty	decb_irq_service_routine, PCR	; We will call it at the end of our own handler

	leax	irq_service_routine, PCR
	stx	IRQ_HANDLER		; Our own interrupt service routine is installed

	bsr	switch_on_irq		; Switch interrupts back on

	rts

***********************************
* Uninstall our IRQ service routine
***********************************

uninstall_irq_service_routine:

        bsr     switch_off_irq

        ldy     decb_irq_service_routine, PCR
        sty     IRQ_HANDLER

        bsr     switch_on_irq

        rts

**********************
* Our IRQ handler
**********************

irq_service_routine:
	lda	#1
	sta	vblank_happened, PCR

					; In the interests of making our IRQ handler run fast,
					; the routine assumes that decb_irq_service_routine
					; has been correctly initialized

	jmp	[decb_irq_service_routine, PCR]

decb_irq_service_routine:
	RZB 2

vblank_happened:
	FCB	0

*****************
* Wait for VBlank
*****************

wait_for_vblank:
	clr	vblank_happened,PCR	; Put a zero in vblank_happened

wait_loop:
	tst	vblank_happened,PCR	; As soon as a 1 appears...
	beq	wait_loop

	lda	#DEBUG_MODE
	beq	exit_wait_for_vblank

	jsr	[POLCAT]
	cmpa	#'T'
	bne	not_t

	com	toggle

not_t:
	tst	toggle
	beq	exit_wait_for_vblank
	cmpa	#'F'
	bne	wait_loop

exit_wait_for_vblank:
	rts				; ...return to caller

toggle:	RZB	1

*********************
* Turn off disk motor
*********************

DSKREG	EQU	$FF40

turn_off_disk_motor:

	clr	DSKREG		; Turn off disk motor
	rts

******************
* Clear the screen
******************

clear_screen:
	ldx	#TEXTBUF
	ldd	#$6060			; Two green boxes

clear_char:
	std	,x+			; Might as well do 8 bytes at a time
	std	,x+
	std	,x+
	std	,x+

	cmpx	#TEXTBUF+TEXTBUFSIZE	; Finish in the lower-right corner
	bne	clear_char
	rts

********************************************************
* Is space bar being pressed?
*
* Output:
* A = 0 if space bar is not pressed
* A = non-zero if space bar is being pressed
********************************************************

POLCAT	EQU	$A000			; ROM routine

check_for_space:
	jsr	[POLCAT]		; A ROM routine
	cmpa	#' '
	beq	skip
	clra
	rts

skip:
	lda	#1
	rts

**********************************************************
* Returns a random-ish number from 0...65535
*
* Output:
* D = the random number
**********************************************************

SEED:
	FCB	0xBE
	FCB	0xEF

get_random:
	ldd	SEED
	mul
	addd	#3037
	std	SEED
	rts

*******************************
* Play a sound sample
*
* Inputs:
* X = The sound data
* Y = The end of the sound data
* A = The delay between samples
*******************************

AUDIO_PORT  	EQU	$FF20		; (the top 6 bits)

play_sound:
	lbsr	switch_off_irq_and_firq

	pshs	y

send_value:
	cmpx	,s			; Compare X with Y

	beq	send_values_finished	; If we have no data, exit

	ldb	,x+
	stb	AUDIO_PORT

	tfr	a,b

sound_delay_loop:
	tstb
	beq	send_value		; Have we completed the delay?

	decb				; If not, then wait some more
	bra	sound_delay_loop

send_values_finished:

	puls	y

	lbsr	switch_on_irq_and_firq

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

*****************************
* Clear area
*
* Inputs:
* X = fulcrum screen position
*****************************

clear_area:
	tfr	x,d
	andb	#0b11100000
	subd	#64
	tfr	d,x
	leay	160,x
	pshs	y

	ldd	#$6060

more_green:
	std	,x++
	std	,x++
	std	,x++
	std	,x++

	cmpx	,s
	bne	more_green

	puls	y
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
	cmpb	#16
	blo	horizontal
	cmpb	#48
	blo	forward_slash
	cmpb	#80
	blo	vertical
	cmpb	#112
	blo	backward_slash
	cmpb	#144
	blo	horizontal
	cmpb	#176
	blo	forward_slash
	cmpb	#208
	blo	vertical
	cmpb	#240
	blo	backward_slash
	bra	horizontal

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

