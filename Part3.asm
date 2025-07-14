* This is Part 3 of Text Mode Demo
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
* ASCII art in the fourth section was made by an unknown person from
* https://www.asciiart.eu/animals/birds-land
* and then modified by me
* ASCII art of the Batman logo was made by an unknown person, possibly
* Joan Stark, at https://www.asciiart.eu/comics/batman
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

	jsr	linux_spoof		; First section
	jsr	game_of_life		; Second section
	jsr	starfield		; Third section
	jsr	multi_scroller		; Fourth section
	jsr	loading_screen

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
* A = 0          -> A VBlank happened
* A = (Non-zero) -> User is trying to skip
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

*************
* Linux spoof
*************

linux_spoof:

	jsr	clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames                     ; Wait a number of frames
	tsta
	bne	skip_linux_spoof

	ldx	#linux_spoof_text
	jsr	display_messages
	tsta
	bne	skip_linux_spoof

	jsr	clear_screen
        lda     #2*WAIT_PERIOD
        jsr     wait_frames                     ; Wait a number of frames
	tsta
	bne	skip_linux_spoof

	lda	#7
	ldb	#13
	ldx	#ha_ha_message
	jsr	display_text_graphic
        lda     #WAIT_PERIOD
        jsr     wait_frames                     ; Wait a number of frames
	tsta
	bne	skip_linux_spoof

	lda	#9
	ldb	#10
	ldx	#just_kidding_message
	jsr	display_text_graphic

	lda	#100
	jsr	wait_frames		; Return the result in A

	rts

skip_linux_spoof:

	lda	#1
	rts

linux_spoof_text:

	FCV	"LOADING LINUX KERNEL...%%%",0
	FCV	"LINUX VERSION 6.11.0-28-GENERIC%",0
	FCV	"KERNEL SUPPORTED CPUS:",0
	FCV	"  MOTOROLA 6809",0
	FCV	"  HITACHI 6309",0
	FCV	"PHYSICAL RAM MAP:%%%",0
	FCV	"[MEM 0X0000-0X7FFF] USABLE%%%%",0
	FCV	"[MEM 0X8000-0FFFF] RESERVED",0
	FCV	"MAX. THREADS PER CORE: 1",0
	FCV	"NUM. CORES PER PACKAGE: 1%%%",0,0
	FCV	"FRAME BUFFER 32X16%",0,0
	FCV	"SPLASH BOOT-IMAGE=/BOOT/VMLINUZ>%%%%%",0
	FCV	"HUB 2-0:1.0: USB HUB NOT FOUND%%%%%%%",0

	FCV	255

ha_ha_message:

	FCV	"HA HA!",0,255

just_kidding_message:

	FCV	"JUST KIDDING!",0,255

**************
* Game of Life
**************

game_of_life:

	jsr	clear_screen

	lda	#WAIT_PERIOD
	jsr	wait_frames	; Ignore return value

_game_of_life_loop:

	ldd	germ_frame
	addd	#1
	std	germ_frame
	cmpd	#1000
	beq	_game_of_life_finished

	jsr	iterate
	jsr	add_germs

	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	_skip_game_of_life

	jsr	copy_buffer

	bra	_game_of_life_loop

_game_of_life_finished:
	clra
	rts

_skip_game_of_life:
	lda	#1
	rts

second_buffer:

	RZB	512, GREEN_BOX

germ_frame:

	RZB	2

add_germ_phase:

	RZB	1

add_germs:

	bsr	add_germ_draw

	lda	add_germ_phase
	beq	_phase0
	cmpa	#1
	beq	_phase1
	cmpa	#2
	beq	_phase2

	; Other phases are not implemented yet
	rts

_phase0:

	lda	#3
	sta	_add_germ_vertical

	ldb	#5
	stb	_add_germ_horizontal

	lda	#1
	sta	add_germ_phase

	rts

_phase1:
	lda	_add_germ_horizontal
	cmpa	#27
	beq	_end_phase_1
	inca
	sta	_add_germ_horizontal

	rts

_end_phase_1:

	lda	#2
	sta	add_germ_phase
	rts

_phase2:
	lda	_add_germ_vertical
	cmpa	#14
	beq	_end_phase_2
	inca
	sta	_add_germ_vertical

	rts

_end_phase_2:

	lda	#3
	sta	add_germ_phase

	rts

_add_germ_horizontal:

	FCB	-1

_add_germ_vertical:

	FCB	-1

WHITE_BOX	EQU	$CF

add_germ_draw:

	lda	#_add_germ_vertical
	bmi	_no_draw
	ldb	#COLS_PER_LINE
	mul
	ldx	#second_buffer
	leax	d,x
	lda	_add_germ_horizontal
	leax	a,x

	lda	#WHITE_BOX
	sta	,x			; Plot a new cell

_no_draw:
	rts

iterate:

	; Fill the second buffer by transforming the first buffer

	lda	#0
	ldb	#0
	ldx	#TEXTBUF
	ldu	#second_buffer

_iterate_loop:
	pshs	a,x,u
	bsr	determine_box_value		; Result in box_value
	puls	a,x,u

	pshs	a
	lda	box_value
	sta	,u				; Store it
	puls	a

	leax	1,x
	leau	1,u
	inca
	cmpa	#COLS_PER_LINE
	blo	_skip_reset

	clra
	incb

_skip_reset:
	cmpx	#TEXTBUFEND
	bne	_iterate_loop

	rts

box_value:

	RZB	1

determine_box_value:

	clr	box_value

	deca	; to the left
	bsr	get_box

	rts		; Return value is in box_value

get_box:
	rts


copy_buffer:

	ldx	#TEXTBUF
	ldu	#second_buffer

_copy_buffer_loop:
	ldd	,u++
	std	,x++

	cmpx	#TEXTBUFEND
	bne	_copy_buffer_loop

	rts

***************
* Starfield
*
* Inputs: None
* Outputs: None
***************

starfield_x_pos:

	RZB	2

starfield:

	jsr	clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames                     ; Ignore attempt to skip

_starfield_loop:
	jsr	wait_for_vblank_and_check_for_skip
	tsta
	bne	_starfield_skip

	ldd	starfield_x_pos

_starfield_has_been_reset:
	ldx	#$8000		; Use the ROM as our data source
	leax	d,x

				; I found this range
				; by inspecting the memory of a Coco
				; using mame -debug

	cmpx	#$D000
	bhs	_reset_starfield

	ldy	#TEXTBUF

_starfield_line_loop:
	bsr	starfield_do_line

	leax	9*COLS_PER_LINE,x

	cmpx	#$D000
	blo	_skip_decrement

	leax	-$5000,x	; Keep in the range $8000-$D000

_skip_decrement:
	cmpy	#TEXTBUF+15*COLS_PER_LINE
	blo	_starfield_line_loop

	ldx	#scroller_starfield	; Add the scroll text at the bottom
	jsr	display_scroll_text	; of the screen

	ldd	scroller_starfield	; As soon as the scroll text is
					; finished, so is this section
	bmi	_starfield_end

	ldd	starfield_x_pos
	addd	#1
	std	starfield_x_pos

	bra	_starfield_loop

_starfield_skip:
	lda	#1
	rts

_starfield_end:
	clra
	rts

_reset_starfield:
	clra
	clrb
	std	starfield_x_pos
	bra	_starfield_has_been_reset

*************************
* Starfield Do Line
*
* Inputs:
* X = Star data
* Y = Screen position
*
* Outputs:
* X = New star data
* Y = New screen position
*************************

starfield_do_line:

	ldb	#COLS_PER_LINE

_starfield_do_line_loop:

	lda	,x+
	cmpa	#123		; Rarely, a planet appears
	beq	_star_planet
	anda	#0b00011111

;	cmpa	#0
	beq	_star_dot

	cmpa	#1
	beq	_star_big

* No star:

	lda	#GREEN_BOX	; and fallthrough

_plot_star:
	sta	,y+

	decb
	bne	_starfield_do_line_loop

	rts	; Return X and Y

_star_dot:
	lda	#'.'+64
	bra	_plot_star

_star_big:
	lda	#'*'+64
	bra	_plot_star

_star_planet:
	lda	#'O'
	bra	_plot_star

***********************
* Multiscroller routine
***********************

multi_scroller:

	jsr	clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames                     ; Wait a number of frames

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
	jsr	wait_for_vblank_and_check_for_skip
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

	jsr	display_scroll_text
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

****************
* Loading screen
****************

loading_screen:

        jsr     clear_screen

        lda     #WAIT_PERIOD
        jsr     wait_frames

        lda     #3
        clrb
        ldx     #batman_logo
        jsr     display_text_graphic

        ldx     #loading_text
        lda     #15
        ldb     #11
        jsr     display_text_graphic
        rts

loading_text:

        FCV     "LOADING...",0

batman_logo:
	FCV	"       .,    .   .    ,.",0
	FCV	"  .O888P     Y8O8Y     Y888O.",0
	FCV	" D88888      88888      88888B",0
	FCV	"D888888B.  .D88888B.  .D888888B",0
	FCV	"8888888888888888888888888888888",0
	FCV	"8888888888888888888888888888888",0
	FCV	"YJGS8P\"Y888P\"Y888P\"Y888P\"Y8888P",0
	FCV	" Y888   '8'   Y8P   '8'   888Y",0
	FCV	"  '8O          V          O8'",0
	FCV	"    '                     '",0
	FCB	255

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

******************
* Display messages
*
* Inputs:
* X = Messages
******************

display_messages:
        ldy     #TEXTBUF

_display_messages_loop:
        ldb     ,x+
        beq     _next_line
        cmpb    #'%' + 64
        beq     _message_pause
        cmpb    #255
        beq     _display_messages_end
        stb     ,y+

        bra     _display_messages_loop  ; User has not skipped

_display_messages_end:
	clra
        rts

_message_pause:
        pshs    a,x,y
        lda     #WAIT_PERIOD
        jsr     wait_frames
        tsta
        puls    a,x,y
        bne     _display_messages_skip
        bra     _display_messages_loop

_next_line:
        pshs    a,x
        tfr     y,d
        addd    #32
        andb    #0b11100000
        tfr     d,y
        puls    a,x
        bra     _display_messages_loop

_display_messages_skip:
	lda	#1
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

scroller_starfield:

	FDB	0	; Starting frame
	FCB	0	; Frame counter
	FCB	5	; Frames to pause
	FDB	scroll_text_starfield
	FDB	TEXTBUF+15*32

scroll_text_starfield:

	FCV	"                                "
	FCV	"STARFIELD SCROLLER"
	FCV	" TESTING TESTING TESTING"
	FCV	"                                "
	FCB	0

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

*******************
* Here is our music
*******************
