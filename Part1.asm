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

DISPL		EQU	$B99C
SAM_TY_SET	EQU	$FFDF
SAM_TY_CLEAR	EQU	$FFDE

* The following number is found through experimentation

		ORG $3000

* Zero the DP register

	clrb
	tfr b, dp

* Check for 64K RAM

	orcc  #0b00010000	; Switch off IRQ interrupts for now

	lda   #$ff
	sta   SAM_TY_SET	; Switch ROM out, upper 32K of RAM in

* This code was modified from some code written by Ciaran Anscomb

	lda $0062
	ldb $8063
	coma
	comb
	std $8062
	cmpd $8062
	lbne ram_not_found
	cmpd $0062
	lbeq ram_not_found

* End code written by Ciaran Anscomb

	lda   #$ff
	sta   SAM_TY_CLEAR	; Switch upper 32K of RAM out, ROM back in

	andcc #0b11101111	; Switch interrupts back on

* Install our IRQ handler

IRQ_HANDLER	EQU	$10d

	orcc  #0b00010000	; Switch off interrupts for now

	ldy IRQ_HANDLER		; Load the current vector into y
	sty decb_irq_service_routine	; We will call it at the end of our own handler

	ldx #irq_service_routine
	stx IRQ_HANDLER		; Our own interrupt service routine is installed

	andcc #0b11101111	; Switch interrupts back on

* Turn on 6-bit audio circuits

	lbsr turn_6bit_audio_on	; Turn on our audio circuits

* This is the text buffer we're using
TEXTBUF		EQU	1024
TEXTBUFSIZE	EQU	512

	ldx #TEXTBUF
	ldy #line_counts	; There are 16 of these

count_chars:
	ldb #32

test_char:
	lda  ,x+
	cmpa #$60		; Is it a space?
	beq  space_char

	inc  ,y			; Count another non-space character

space_char:
	decb
	bne test_char

	cmpx #TEXTBUF+TEXTBUFSIZE
	beq count_chars_finished

	leay 1,y		; Start counting the next line
	bra count_chars

count_chars_finished:

check_text_screen_empty:
	ldy #line_counts

test_line:
	tst  ,y+
	bne  not_empty
	cmpy #line_counts+16
	bne test_line

empty:
	bra screen_is_empty

not_empty:
	ldy #line_counts

choose_line:
	lbsr get_random 	; Get a random number in D

	clra
	andb #0b00001111	; Make it between 0 and 15

	tst b,y			; If there are no more characters on this line
	beq choose_line		; choose a different one

	dec b,y			; There'll be one less character now

	lda #32
	mul 			; Multiply b by 32 and put the answer in D

	ldx #TEXTBUF+32		; Make X point to the end of the line
	leax d,x		; that we will pluck from

	lda #$60		; Space

find_non_space:
	cmpa ,-x		; Go backwards until we find a non-space
	beq find_non_space

	ldb ,x			; Save the character in B

	pshs b,x,y
	ldx #pluck_sound	; Play the pluck noise
	ldy #pluck_sound_end
	lbsr play_sound
	puls b,x,y

POLCAT	EQU	$A000		; ROM routine

pluck_loop:
	jsr [POLCAT]		; Is the spacebar being pressed?
	cmpa #' '
	bne do_pluck		; No, then keep plucking

	lbsr clr		; Yes, then clear the screen
	bra screen_is_empty	; And go to the next part

do_pluck:
	lbsr wait_for_vblank	; This is how we time

	lda #$60
	sta ,x+			; Replace it with a space

	tfr d,y			; Save the character in lower byte of Y
	tfr x,d
	andb #0b00011111	; Is the address divisible by 32?

	bne move_character	; No, keep shifting it

				; Yes, fallthrough because we've reached the right
				;   side of the screen

	bra check_text_screen_empty	; Go back and start again

move_character:
	tfr y,d			; Get the character being saved back in B

	stb ,x			; Put the character one position to the right
	bra pluck_loop

screen_is_empty:

	nop

title_screen:
	ldy #title_screen_text

print_text_loop:
	lda ,y+
	ldb ,y+
	tfr y,x

	pshs y
	lbsr text_appears
	puls y

find_zero:
	tst ,y+
	bne find_zero

	lda #255		; This marks the end of the text lines
	cmpa ,y			; Is that what we have?
	bne print_text_loop	; If not, then print the next line
				; If yes, then fall through to the next section

end:
	bra end
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

line_counts:
	RZB 16			; 16 zeroes.

* This routine clears the first text buffer
clr:
	ldx #TEXTBUF
	lda #$60

clear_char:
	sta ,x+

	cmpx #TEXTBUF+TEXTBUFSIZE
	bne clear_char
	rts

SEED:
	FCB 0xBE
	FCB 0xEF

* Returns a random-ish number from 0...65535 in register D

get_random:
	ldd SEED
	mul
	addd #3037
	std SEED
	rts

vblank_happened:
	FCB 0

irq_service_routine:
	lda #1
	sta vblank_happened

	jmp [decb_irq_service_routine]

decb_irq_service_routine:
	RZB 2

wait_for_vblank:
	clra
	sta  vblank_happened	; Put a zero in vblank_happened

wait_loop:
	tst  vblank_happened	; As soon as a 1 appears...
	beq  wait_loop

	rts			; ...return to caller

turn_6bit_audio_on:
AUDIO_PORT_ON	EQU $FF23		; Port Enable Audio (bit 3)
PIA2_CRA	EQU $FF21
DDRA		EQU $FF20
AUDIO_PORT  	EQU $FF20		; (top 6 bits)

* This code was modified from code written by Trey Tomes.

	lda AUDIO_PORT_ON
	ora #0b00001000
	sta AUDIO_PORT_ON	; Turn on 6-bit audio

* End code written by or modified from code written by Trey Tomes

* This code was written by other people.

	ldb PIA2_CRA
	andb #0b11111011
	stb PIA2_CRA

	lda #0b11111100
	sta DDRA

	orb #0b00000100
	stb PIA2_CRA

* End of code written by other people

	rts

* This plays any sound sample
* X = The sound data
* Y = The end of the sound data

play_sound:
	orcc #0b01010000	; Turn off IRQ and FIRQ
	clr  $ff40		; Turn off disk motor

	stx sound_bytes		; X is the start of the sample
	tfr y,d
	subd sound_bytes	; D is the length of our sample

send_value:
	lda ,x+
	sta AUDIO_PORT		; Poke the relevant value into Audio Port

	subd #1
	blo  send_value

	andcc #0b10101111	; Turn IRQ and FIRQ back on

	rts

sound_bytes:
	RZB 2

ram_not_found:
	lda   #$ff
	sta   SAM_TY_CLEAR	; Switch ROM back in

	andcc #0b11101111	; Switch interrupts back on

	clr $6F			; Output to the screen
	ldx #ram_error_message-1
	JSR DISPL		; Put the string to the screen
	rts

ram_error_message:
	FCV "YOU"
	FCB $8f
	FCV "NEED"
	FCB $8f
	FCB 54			;64k
	FCB 52
	FCV "K"
	FCB $8f
	FCV "RAM"
	FCB $8f
	FCV "FOR"
	FCB $8f
	FCV "THIS"
	FCB $8f
	FCV "DEMO"
	FCB $22			; A quotation mark ends the string

ram_error_end:

* Brings text onto the screen using an animation
* X = string to print
* A = line number (0 to 15)
* B = character position (0 to 31)

text_appears:
	tfr x,u			; U = string to print
	pshs b
	ldy #TEXTBUF
	ldb #32
	mul
	leax d,y		; X is where to start the animation
	puls b			; B is the character position to start
				;   printing the string

buff_box:
	lda #$cf		; A buff box
	sta ,x			; Put it on the screen

	pshs b,x,u
	lbsr wait_for_vblank
	puls b,x,u

	tstb			; If non-zero, we are not printing out
	bne green_box		; yet

	lda ,u+			; Get the next character from the string
	bne store_char		; And put it on the screen

	leau -1,u		; It was a zero we retrieved: Repoint U
				; And fall through to using a green box

green_box:
	tstb
	beq skip_decrement

	decb

skip_decrement:
	lda #$60		; Put a green box in A

store_char:
	sta ,x+			; Put the relevant character (green box or char) into
				;   the relevant position

	stx  test_area
	lda  #0b11111
	anda test_area+1	; Is the character position divisible by 32?

	bne buff_box		; If no, then go back and do it again
	rts

test_area:
	RZB 2

pluck_sound:
	INCLUDEBIN "Pluck.raw"
pluck_sound_end:

* We have two text buffers, to enable double buffering
* Memory locations 1024-1535 and 1536-2047
TEXTBUF2	EQU	1536

