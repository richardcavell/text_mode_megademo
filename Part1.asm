* This is Part 1 of Text Mode Demo
* by Richard Cavell
* June 2025
*
* This file is intended to be assembled by asm6809, which is
* written by Ciaran Anscomb
*
* Part of this code was written by Trey Tomes. You can see it here:
* https://treytomes.wordpress.com/2019/12/31/a-rogue-like-in-6809-assembly-pt-2/
* Part of this code was written by other authors. You can see it here:
* https://github.com/cocotownretro/VideoCompanionCode/blob/main/AsmSound/Notes0.1/src/Notes.asm
* Part of this code was written by Ciaran Anscomb
* You can visit his website at https://6809.org.uk

* This starting location is found through experimentation with mame -debug
* and the CLEAR command

		ORG $1800

**********************
* Zero the DP register
**********************

	clrb
	tfr	b, dp

*******************
* Check for 64K RAM
*******************

	lbsr	switch_off_irq		; Switch off IRQ interrupts for now
	lbsr	set_sam_ty		; Switch ROM out, upper 32K of RAM in

	; This code was modified from some code written by Ciaran Anscomb

	lda	$0062
	ldb	$8063
	coma
	comb
	std	$8062
	cmpd	$8062
	bne	ram_not_found
	cmpd	$0062
	beq	ram_not_found

	; End code written by Ciaran Anscomb

	lbsr	clear_sam_ty		; Switch upper 32K RAM out, ROM in
	lbsr	switch_on_irq		; Switch IRQ interrupts back on
	bra	ram_check_end

ram_not_found:
	lbsr	clear_sam_ty
	lbsr	switch_on_irq

	ldx	#ram_error_message
	lbsr	display_message

	lda	#$01
	rts				; Return to the operating system

ram_error_message:
	FCV	"YOU"
	FCB	$8f			; blank space
	FCV	"NEED"
	FCB	$8f
	FCB	54			; '6'
	FCB	52			; '4'
	FCV	"K"
	FCB	$8f
	FCV	"RAM"
	FCB	$8f
	FCV	"FOR"
	FCB	$8f
	FCV	"THIS"
	FCB	$8f
	FCV	"DEMO"
	FCB	$22			; A quotation mark ends the error message

ram_check_end:

*************************
* Install our IRQ handler
*************************

	lbsr	install_irq_service_routine

*************************
* Turn off the disk motor
*************************

	lbsr	turn_off_disk_motor

******************************
* Turn on 6-bit audio circuits
******************************

	lbsr	turn_6bit_audio_on

***********************************************************
* Pluck routine - make characters disappear from the screen
***********************************************************

TEXTBUF		EQU	$400		; We're not double-buffering
TEXTBUFSIZE	EQU	$200		; so there's only one text screen

; First, count the number of characters on each line of the screen

	ldx	#TEXTBUF
	ldy	#line_counts		; There are 16 of these

count_chars_on_one_line:
	ldb	#32			; There are 32 characters per line

test_char:
	lda	,x+
	cmpa	#$60			; Is it a space?
	beq	space_char

	inc	,y			; Count another non-space character

space_char:
	decb
	bne	test_char

	cmpx	#TEXTBUF+TEXTBUFSIZE
	beq	count_chars_end

	leay	1,y			; Start counting the next line
	bra	count_chars_on_one_line

line_counts:
	RZB 16			; 16 zeroes
line_counts_end:

count_chars_end:

; Now, check to see if the screen is empty yet

check_text_screen_empty:
	ldy	#line_counts

test_line:
	tst	,y+
	bne	not_empty
	cmpy	#line_counts_end
	bne	test_line

empty:
	bra	screen_is_empty	; Go to the next piece of this demo

not_empty:

choose_line:
	lbsr	get_random 	; Get a random number in D
	ldy	#line_counts

	clra
	andb	#0b00001111	; Make it between 0 and 15

	tst	b,y		; If there are no more characters on this line
	beq	choose_line	; choose a different one

	dec	b,y		; There'll be one less character now

	lda	#32
	mul 			; Multiply b by 32 and put the answer in D

	ldx	#TEXTBUF+32	; Make X point to the end of the line
	leax	d,x		; that we will pluck from

	lda	#$60		; Green box (space)

find_non_space:
	cmpa	,-x		; Go backwards until we find a non-space
	beq	find_non_space

				; X = position of the character we're plucking
	ldb	,x		; B = the character

	pshs	b,x
	ldx	#pluck_sound
	ldy	#pluck_sound_end
	lda	#1
	lbsr	play_sound			; Play the pluck noise
	puls	b,x

POLCAT	EQU	$A000		; ROM routine

pluck_loop:
	pshs	b,x
	jsr	[POLCAT]
	cmpa	#' '		; Check for space bar being pressed
	puls	b,x		; Does not affect CCs
	bne	do_pluck	; If not, then continue plucking

	lbsr	clear_screen	; If so, clear the screen
	bra	screen_is_empty	; and skip this section

do_pluck:
	lbsr	wait_for_vblank	; This is how we time

	lda	#$60
	sta	,x+		; Replace it with a space

	tfr	d,y		; Save the character in the lower byte of Y
	tfr	x,d
	andb	#0b00011111	; Is the address divisible by 32?

	beq	check_text_screen_empty	; Yes, then we have reached the right side
				; of the screen, so start another pluck

move_character:
	tfr	y,d		; Get the character being saved back in B

	stb	,x		; Put the character one position to the right
	bra	pluck_loop

screen_is_empty:

**************
* Title screen
**************

title_screen:
	ldy	#title_screen_text

print_text_loop:
	lda	,y+
	ldb	,y+
	tfr	y,x

	pshs	y
	lbsr	text_appears
	puls	y

find_zero:
	tst	,y+
	bne	find_zero

	lda	#255			; This marks the end of the text
					;   lines
	cmpa	,y			; Is that what we have?
	bne	print_text_loop		; If not, then print the next line
					; If yes, then fall through to the
					;   next section

	ldx	#rjfc_presents_tmd_sound	; Start of sound
	ldy	#rjfc_presents_tmd_sound_end	; End of sound
	lda	#8
	lbsr	play_sound		; Play the sound

	lda	#5
	ldb	#0
	lbsr	encase_text		; "Encase" the three text items

	lda	#8
	ldb	#1
	lbsr	encase_text

	lda	#12
	ldb	#0
	lbsr	encase_text

	lda	#5
	ldb	#3
	lbsr	flash_text_white

	lda	#8
	ldb	#3
	lbsr	flash_text_white

	lda	#12
	ldb	#3
	lbsr	flash_text_white

	lbsr	flash_screen
	lbsr	flash_screen
	lbsr	flash_screen

* Drop the lines off the bottom end of the screen

	lda	#11
	lbsr	drop_screen_content

	lda	#7
	lbsr	drop_screen_content

	lda	#4
	lbsr	drop_screen_content

skip_title_screen:		; If space was pressed
	lbsr	clear_screen	; Just clear the screen

**************
* Create a dot
**************

DOT_START	EQU	(TEXTBUF+8*32+16)

	ldx	#DOT_START	; in the middle of the screen

	lda	#'*'+64		; Non-inverted asterisk
	sta	,x

	ldb	#10		; Wait this number of frames

dot_wait:
	pshs	b
	lda	#1
	ldx	#skip_dot
	jsr	check_space
	puls	b

	pshs	b
	lbsr	wait_for_vblank
	puls	b
	decb
	bne	dot_wait

***************
* The dot moves
***************

	bra	dot_moves

scale_factor:
	RZB	2		; Fixed point scale factor
angle:
	RZB	1		; 0-255 out of 256
sine_of_angle:
	RZB	2		; 256 to -256
dot_previous:
	RZB	2		; Previously drawn location of dot
displacement:
	RZB	1		; The amount that the dot moves
new_position:
	RZB	2		; The calculated new position

dot_moves:
				; First, set everything to 0

	ldd	#0		; Our scale factor
	std	scale_factor

	lda	#0		; A is our angle
	sta	angle		; (A fixed-point fraction)

	ldd	#0
	std	sine_of_angle	; The sine will be calculated later

	ldd	#DOT_START	; the previous location of the dot
	std	dot_previous

	lda	#0
	sta	displacement

	ldd	#0
	std	new_position

move_dot:
	clra			; A is really don't care
	ldb	angle		; D is our angle in fixed point
	lbsr	sin		; D is now the sine of our angle
	std	sine_of_angle

	ldx	scale_factor		; X = scale factor, D is sine

	lbsr	multiply_fixed_point	; multiply D by X (scale by sine)
	lbsr	round_to_nearest	; Need to round this up or down
	sta	displacement		; This is the displacement

	lda	#0
	ldx	#skip_dot
	jsr	check_space

	jsr	wait_for_vblank

	lda	#$60		; Green box
	ldx	dot_previous
	sta	,x		; Erase previous dot

	lda	displacement
	ldx	#DOT_START
	leax	a,x		; X is now the position of the new dot

	lda	#'*' + 64
	sta	,x		; Draw the new dot
	stx	dot_previous	; And erase after next VBlank

	ldd	scale_factor	; Increase the scale factor
	addd	#100		; gradually

	cmpd	#2000		; If D is over 2000,
	blt	d_is_clamped

	ldd	#2000		; Make it equal to 2000

d_is_clamped:
	std	scale_factor

	lda	angle		; (A fixed-point fraction)
	adda	#2		; It rotates constantly
	sta	angle

	bra	move_dot

skip_dot:	; This is one of the addresses given to check_space

	lbsr	clear_screen

end:
	rts

title_screen_text:
	FCB 5, 6
	FCN "RJFC"	; Each string ends with a zero when you use FCN
	FCB 8, 10
	FCN "PRESENTS"
	FCB 12, 12
	FCC "TEXT"
	FCB $8F
	FCC "MODE"
	FCB $8F
	FCC "DEMO"
	FCB 0
	FCB 255		; The end

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

*********************
* Turn off disk motor
*********************

DSKREG	EQU	$FF40

turn_off_disk_motor:

	clr	DSKREG		; Turn off disk motor
	rts

**********************************
* Switch SAM TY register on or off
**********************************

SAM_TY_SET	EQU	$FFDF
SAM_TY_CLEAR	EQU	$FFDE

set_sam_ty:

	lda	#$ff
	sta	SAM_TY_SET	; Switch ROM out, upper 32K of RAM in
	rts

clear_sam_ty:

	lda	#$00
	sta	SAM_TY_CLEAR	; Switch upper 32K of RAM out, ROM back in
	rts

************************************************************
* Display a message using the operating system
*
* Input:
* X = string containing the message (ended by double quotes)
************************************************************

DISPL		EQU	$B99C

display_message:

	clr	$6F			; Output to the screen
	leax	-1,x			; The first character is skipped over
	JSR	DISPL			; Put the string to the screen
	rts

*********************************
* Install our IRQ service routine
*********************************

IRQ_HANDLER	EQU	$10d

install_irq_service_routine:

	bsr	switch_off_irq		; Switch off interrupts for now

	ldy	IRQ_HANDLER			; Load the current vector into y
	sty	decb_irq_service_routine	; We will call it at the end of our own handler

	ldx	#irq_service_routine
	stx	IRQ_HANDLER		; Our own interrupt service routine is installed

	bsr	switch_on_irq		; Switch interrupts back on

	rts

**********************
* Our IRQ handler
**********************

vblank_happened:
	FCB	0

irq_service_routine:
	lda	#1
	sta	vblank_happened

					; In the interests of making our IRQ handler run fast,
					; the routine assumes that decb_irq_service_routine
					; has been correctly initialized

	jmp	[decb_irq_service_routine]

decb_irq_service_routine:
	RZB 2

*********************
* Turn 6-bit audio on
*********************

AUDIO_PORT  	EQU	$FF20		; (the top 6 bits)
DDRA		EQU	$FF20
PIA2_CRA	EQU	$FF21
AUDIO_PORT_ON	EQU	$FF23		; Port Enable Audio (bit 3)

turn_6bit_audio_on:

* This code was modified from code written by Trey Tomes

	lda	AUDIO_PORT_ON
	ora	#0b00001000
	sta	AUDIO_PORT_ON	; Turn on 6-bit audio

* End code modified from code written by Trey Tomes

* This code was written by other people (see the top of this file)

	ldb	PIA2_CRA
	andb	#0b11111011
	stb	PIA2_CRA

	lda	#0b11111100
	sta	DDRA

	orb	#0b00000100
	stb	PIA2_CRA

* End of code written by other people

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

play_sound:
	bsr	switch_off_irq_and_firq

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

	bsr	switch_on_irq_and_firq

	rts

***********************************
* Play a repeating sound sample
*
* Inputs:
* X = The sound data
* Y = The end of the sound data
* U The repeat start point, then
* (Pushed onto S)
*   The repeat end point
* A = The delay between samples
* B = The number of times to repeat
***********************************

play_repeating_sound:

	pshs	d			; Add 1 to the repeat end point
	ldd	4,s
	addd	#1
	std	4,s
	puls	d

	pshs	y			; ,s is equal to y
					; 4,s is equal to the repeat end point

        lbsr	switch_off_irq_and_firq

play_repeating_sound_loop:

	cmpx	,s
	beq	play_repeating_sound_finished

	tstb
	beq	play_repeating_no_rpta

	cmpx	4,s
	bne	play_repeating_no_rptb

	tfr	u,x			; Send the marker back to the
					;   repeat start

	decb

	bra play_repeating_no_rptb

play_repeating_no_rpta:
	nop
	nop
	nop
	nop
	nop
	nop

play_repeating_no_rptb:

	pshs	a
	lda	,x+
	sta	AUDIO_PORT		; Send the sample to the audio port
	puls	a

	pshs	a

play_repeating_delay_loop:

	deca
	bne	play_repeating_delay_loop

	puls	a

	bra	play_repeating_sound_loop

play_repeating_sound_finished:
	leas	4,s			; Undo the pushes onto the stack
					;   and throw away the values that
					;   were there

	lbsr	switch_on_irq_and_firq

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

*****************
* Wait for VBlank
*****************

wait_for_vblank:
	clr	vblank_happened		; Put a zero in vblank_happened

wait_loop:
	tst	vblank_happened		; As soon as a 1 appears...
	beq	wait_loop

	rts				; ...return to caller

********************************************************
* Is space bar being pressed?
*
* Inputs:
* A = number of bytes on S stack that need to be removed
* X = address to skip to if space bar is pressed
********************************************************

check_space:
	pshs	a,b,x,y,u		; Save all registers
	jsr	[POLCAT]		; A ROM routine
	cmpa	#' '
	puls	a,b,x,y,u		; Does not affect CCs
	beq	skip

	rts

skip:
	leas	2,s			; Remove the return address
	leas	a,s			; And any other return addresses
					;   and stack contents
	jmp	,x			; Skip to next section

************************************************
* Brings text onto the screen using an animation
* X = string to print
* A = line number (0 to 15)
* B = character position (0 to 31)
************************************************

text_appears:
	tfr	x,u		; U = string to print
	pshs	b
	ldy	#TEXTBUF
	ldb	#32
	mul
	leax	d,y		; X is where to start the animation
	puls	b		; B is the character position to start
				;   printing the string

buff_box:
	lda	#$cf		; A buff box
	sta	,x		; Put it on the screen

	pshs	b,x,u
	lda	#7
	ldx	#skip_title_screen
	bsr	check_space	; Space bar skips this section
	puls	b,x,u

	pshs	b,x,u
	bsr	wait_for_vblank
	puls	b,x,u

	tstb			; If non-zero, we are not printing out
	bne	green_box	; yet

	lda	,u+		; Get the next character from the string
	bne	store_char	; And put it on the screen

	leau	-1,u		; It was a zero we retrieved: Repoint U
				; And fall through to using a green box

green_box:
	tstb
	beq	skip_decrement

	decb

skip_decrement:
	lda	#$60		; Put a green box in A

store_char:
	sta	,x+		; Put the relevant character (green box or char) into
				;   the relevant position

	stx	test_area
	lda	#0b11111
	anda	test_area+1	; Is the character position divisible by 32?

	bne	buff_box	; If no, then go back and do it again
	rts

test_area:
	RZB	2

*************************************
* Encases text on the screen
* A = line number
* B = direction (0 = right, 1 = left)
*************************************

encase_text:
	tfr	d,y		; Y (lower 8 bits) is direction

	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x		; X is our starting position

	tfr	y,d		; B is direction
	tstb			; If 0, start on the left side
	beq	encase_text_loop

	leax	31,x		; If 1, start on the right side
				; and fallthrough

encase_text_loop:
	pshs	b,x
	lda	#5
	ldx	#skip_title_screen
	lbsr	check_space	; Space bar exits this
	puls	b,x

	pshs	b,x
	lbsr	wait_for_vblank	; Start on the next frame
	puls	b,x

encase_text_more:
	lda	#$60		; Green box (space)

	cmpa	,x		; If x points to a green box...
	bne	encase_char_found

	lda	#125		; then put a '=' in it

	tstb
	bne	encase_backwards

	sta	,x+		; and increment
	bra	encase_finished_storing

encase_backwards:
	sta	,x
	leax	-1,x		; and decrement

encase_finished_storing:
	bra	encase_are_we_done	; Go back and do the next one

encase_char_found:
	lda	#125		; This is '='
	sta	-32,x		; add '=' above
	sta	32,x		;   and below

	tstb
	bne	encase_chars_found_backwards

	leax	1,x		; fallthrough
	bra	encase_are_we_done

encase_chars_found_backwards:
	leax	-1,x
				; fallthrough
encase_are_we_done:
	tstb
	beq	encase_right	; If we're going right

	tfr	d,y
	tfr	x,d
	andb	#0b00011111
	cmpb	#0b00011111	; If X mod 32 == 31
	tfr	y,d
	bne	encase_text_loop
	rts

encase_right:
	tfr	d,y
	tfr	x,d
	andb	#0b00011111	; If X is evenly divisible
	tfr	y,d
	bne	encase_text_loop	;   by 32, then

	rts			; we are finished

**************************************
* Flashes text with white (buff) boxes
*
* Inputs:
* A = line number (0 to 15)
* B = number of times to flash
**************************************

flash_text_white:
	pshs	b

	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x		; X = starting position

	ldy	#flash_text_storage

flash_copy_line:
	ldd	,x++		; Save the whole line
	std	,y++

	cmpy	#flash_text_storage_end
	bne	flash_copy_line

				; Now the line has been saved,
				; Turn all text to white

	leax	-32,x		; Back to the start of the line

	puls	b

flash_chars_loop:
	pshs	b,x
	bsr	flash_chars_white
	puls	b,x

	pshs	b,x
	lda	#5
	ldx	#skip_title_screen
	lbsr	check_space
	puls	b,x

	pshs	b,x
	lbsr	wait_for_vblank
	puls	b,x

	pshs	b,x
	bsr	restore_chars
	puls	b,x

	pshs	b,x
	lda	#5
	ldx	#skip_title_screen
	lbsr	check_space
	puls	b,x

	pshs	b,x
	lbsr	wait_for_vblank
	puls	b,x

	tstb			; We do this routine b times
	beq	flash_finished

	decb
	bra	flash_chars_loop

flash_finished:
	rts			; Done, go away now

*********************************
* Turns all chars on a line white
*********************************

flash_chars_white:
	lda	,x

	cmpa	#125		; '='
	beq	not_flashable

	cmpa	#65		; Is it from A to
	blo	not_flashable
	cmpa	#127		; Question mark
	bhi	not_flashable

	lda	#$cf		; a buff box
	sta	,x		; store it, and fall through

not_flashable:
	leax	1,x
	tfr	x,d
	andb	#0b00011111	; Calculate x mod 32
	bne	flash_chars_white	; If more, go back

	rts

*****************************************
* Restore the chars from our storage area
*
* Inputs:
* X = pointer to start of the line
*****************************************

restore_chars:
	ldy	#flash_text_storage

flash_restore_chars:
	ldd	,y++
	std	,x++

	cmpy	#flash_text_storage_end
	bne	flash_restore_chars

	rts

flash_text_storage:
	RZB	32
flash_text_storage_end:


**************************
* Flashes the screen white
*
* Inputs:
*   none
**************************

flash_screen:
	ldx	#TEXTBUF
	ldy	#flash_screen_storage

flash_screen_copy_loop:
	ldd	,x++			; Make a copy of everything on the screen
	std	,y++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	flash_screen_copy_loop

	lda	#2
	ldx	#skip_title_screen
	lbsr	check_space

	lbsr	wait_for_vblank

	ldx	#TEXTBUF
	ldd	#$cfcf

flash_screen_white_loop:
	std	,x++			; Make the whole screen buff color
	std	,x++
	std	,x++
	std	,x++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	flash_screen_white_loop

	lda	#2
	ldx	#skip_title_screen
	lbsr	check_space
	lbsr	wait_for_vblank

	lda	#2
	ldx	#skip_title_screen
	lbsr	check_space
	lbsr	wait_for_vblank

	ldx	#TEXTBUF
	ldy	#flash_screen_storage

flash_screen_restore_loop:
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++

	cmpx	#TEXTBUF+TEXTBUFSIZE
	bne	flash_screen_restore_loop

	lda	#2
	ldx	#skip_title_screen
	lbsr	check_space

	lbsr	wait_for_vblank

	lda	#2
	ldx	#skip_title_screen
	lbsr	check_space

	lbsr	wait_for_vblank

	rts

********************************
* Drop screen content
*
* Inputs:
* A = starting line
********************************

drop_screen_content:
	pshs	a
	inca
	inca
	bsr	drop_line		; Drop the bottom line
	puls	a

	pshs	a
	inca
	bsr	drop_line		; Drop the middle line
	puls	a

	pshs	a
	bsr	drop_line		; Drop the top line
	puls	a

	pshs	a
	bsr	clear_line		; Clear the top line
	puls	a


	pshs	a
	lda	#3
	ldx	#skip_title_screen
	lbsr	check_space
	puls	a

	pshs	a
	lbsr	wait_for_vblank
	puls	a

	pshs	a
	lda	#3
	ldx	#skip_title_screen
	lbsr	check_space
	puls	a

	pshs	a
	lbsr	wait_for_vblank
	puls	a

	inca				; Next time, start a line lower

	cmpa	#16			; until the starting position is off
					; the screen
	bne	drop_screen_content
	rts

drop_line:
	cmpa	#15
	blo	do_drop

	rts				; Off the bottom end of the screen

do_drop:
	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x			; X = pointer to a line of the screen

	ldb	#32

move_line_down:
	lda	,x			; Retrieve the character
	sta	32,x			; and store it one line below
	leax	1,x

	decb
	bne	move_line_down

	rts

clear_line:
	cmpa	#16
	blo	do_clear

	rts				; Off the bottom end

do_clear:
	ldb	#32
	mul
	ldx	#TEXTBUF
	leax	d,x

	ldb	#8

	lda	#$60

clear_loop:
	sta	,x+
	sta	,x+
	sta	,x+
	sta	,x+

	decb
	bne	clear_loop

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
	ldx	#sin_table
	leax	b,x
	ldd	b,x		; Put sin_table + 2 * B into D

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

result_sign:	RZB	0

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

**************************
* Round to nearest
*
* Input:
* D = fixed point number
*
* Output:
* D = that number, rounded
**************************

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
	bpl	no_adjust_a		; If closest to a, return a

	suba	#1
	cmpa	#127
	bne	done_adjusting_a	; Has it overflowed?

	lda	#128			; Yes, then set D to the largest
	ldb	#255			; negative number

done_adjusting_a:
no_adjust_a:
	clrb
	rts

*************************************
* Here is our raw data for our sounds
*************************************

flash_screen_storage:			; Use the area of memory reserved for
					; the pluck sound, because we're not
					; using it again

pluck_sound:
	INCLUDEBIN "Sounds/Pluck.raw"
pluck_sound_end:

rjfc_presents_tmd_sound:
	INCLUDEBIN "Sounds/RJFC_presents.raw"	; Simply concatenate these
	INCLUDEBIN "Sounds/text_mode_demo.raw"	; two files
rjfc_presents_tmd_sound_end:
