# Makefile
# Part of Name of Demo by Richard Cavell
# June 2025

DISK		=	NNDEMO.DSK
BASIC_PART	=	DEMO.BAS
PART1		=	PART1.BIN
PART2		=	PART2.BIN

PART1_SRC	= 	Part1.asm
PART2_SRC	= 	Part2.asm

PLUCK_SOUND	=	Pluck.raw
PLUCK_SOUND_SRC	=	Sounds/Modelm.wav
PLUCK_SOUND_UNS	=	Pluck_unstripped.raw
SOUND_STR_SRC	=	sound_stripper.c
SOUND_STR	=	sound_stripper

# asm6809 is by Ciaran Anscomb
ASM		=	asm6809 -v
CC		=	gcc
CFLAGS		=	-std=c89 -Wall -Wextra -Werror -Wpedantic -fmax-errors=1

.DEFAULT: all

.PHONY:	all clean disk help info mame mame-debug xroar

all:	$(DISK) $(PART1) $(PART2) $(SOUND_STR) $(PLUCK_SOUND)
disk:	$(DISK)

$(DISK): $(BASIC_PART) $(PART1) $(PART2)
	@echo "Compiling disk" $@
	@rm -f -v $@
	decb dskini $@ -3
	decb copy $(BASIC_PART) -r -t $(DISK),$(BASIC_PART)
	decb copy -2 -b -r $(PART1) $(DISK),$(PART1)
	decb copy -2 -b -r $(PART2) $(DISK),$(PART2)
	@echo "Done"

$(PART1): $(PART1_SRC) $(PLUCK_SOUND)
	@echo "Assembling" $@
	$(ASM) -o $@ -C $<
	@echo "Done"

$(PART2): $(PART2_SRC)
	@echo "Assembling" $@
	$(ASM) -o $@ -C $<
	@echo "Done"

$(SOUND_STR): $(SOUND_STR_SRC)
	@echo "Compiling" $@
	$(CC) $(CFLAGS) -o $@ $<
	@echo "Done"

$(PLUCK_SOUND_UNS): $(PLUCK_SOUND_SRC)
	@rm -v -f $@
	@echo "Resampling" $@
	ffmpeg -i $< -v warning -af 'aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular' -f u8 -c:a pcm_u8 $@
	@echo "Done"

$(PLUCK_SOUND): $(PLUCK_SOUND_UNS) $(SOUND_STR)
	@echo "Soundstripping" $@
	./$(SOUND_STR) $< $@
	@echo "Done"

help: info

info:
	@echo "This demo has no name yet"
	@echo "by Richard Cavell"
	@echo "make all"
	@echo "make clean"
	@echo "make disk"
	@echo "make info"
	@echo "make mame"
	@echo "make mame-debug"
	@echo "make xroar"

clean:
	@rm -v $(DISK) $(PART1) $(PART2) $(SOUND_STR) $(PLUCK_SOUND_UNS) $(PLUCK_SOUND)

mame: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r"

mame-debug: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r" -debug

xroar: $(DISK)
	xroar -m coco2b -load-fd0 $(DISK) -type "RUN \"DEMO\"\r"
