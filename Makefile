# Makefile
# Part of Name of Demo by Richard Cavell
# June 2025
# v1.0

DISK		=	NNDEMO.DSK
BASIC_PART	=	DEMO.BAS
PART1		=	PART1.BIN
PART2		=	PART2.BIN

PART1_SRC	= 	Part1.asm
PART2_SRC	= 	Part2.asm

PLUCK_SOUND	=	Sounds/Pluck.raw
PLUCK_SOUND_SRC	=	Sounds/Modelm.wav
PLUCK_SOUND_UNS	=	Sounds/Modelm_unstripped.raw

RJFC_SOUND	=	Sounds/RJFC_presents.raw
RJFC_SOUND_SRC	=	Sounds/RJFC_presents.wav
RJFC_SOUND_UNS	=	Sounds/RJFC_presents_unstripped.raw

TMD_SOUND	=	Sounds/text_mode_demo.raw
TMD_SOUND_SRC	=	Sounds/textmodedemo.wav
TMD_SOUND_UNS	=	Sounds/textmodedemo_unstripped.raw

SOUND_STR_SRC	=	sound_stripper.c
SOUND_STR	=	sound_stripper

# asm6809 is by Ciaran Anscomb
ASM		=	asm6809
ASMFLAGS	=	-C -v

# You can change this to your favorite C compiler
CC		=	gcc
CFLAGS		=	-std=c89 -Wpedantic -Wall -Wextra -Werror -O2
CFLAGS		+=	-fmax-errors=1

.DEFAULT: all

.PHONY:	all clean disk help info mame mame-debug xroar

all:	$(DISK) $(DISK_IMG) $(PART1) $(PART2) $(SOUND_STR)
all:	$(PLUCK_SOUND) $(RJFC_SOUND) $(TMD_SOUND)
disk:	$(DISK)

$(DISK): $(DISK_IMG) $(BASIC_PART) $(PART1) $(PART2)
	@rm -f -v $@
	@echo "Compiling disk" $@
	decb dskini $@ -3
	decb copy $(BASIC_PART) -r -t $(DISK),$(BASIC_PART)
	decb copy -2 -b -r $(PART1) $(DISK),$(PART1)
	decb copy -2 -b -r $(PART2) $(DISK),$(PART2)
	@echo "Done"

$(PART1): $(PART1_SRC) $(PLUCK_SOUND) $(RJFC_SOUND) $(TMD_SOUND)
	@echo "Assembling" $@
	$(ASM) $(ASMFLAGS) -o $@ $<
	@echo "Done"

$(PART2): $(PART2_SRC)
	@echo "Assembling" $@
	$(ASM) $(ASMFLAGS) -o $@ $<
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

$(RJFC_SOUND_UNS): $(RJFC_SOUND_SRC)
	@rm -v -f $@
	@echo "Resampling" $@
	ffmpeg -i $< -v warning -af 'aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular' -f u8 -c:a pcm_u8 $@
	@echo "Done"

$(RJFC_SOUND): $(RJFC_SOUND_UNS) $(SOUND_STR)
	@echo "Soundstripping" $@
	./$(SOUND_STR) $< $@
	@echo "Done"

$(TMD_SOUND_UNS): $(TMD_SOUND_SRC)
	@rm -v -f $@
	@echo "Resampling" $@
	ffmpeg -i $< -v warning -af 'aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular' -f u8 -c:a pcm_u8 $@
	@echo "Done"

$(TMD_SOUND): $(TMD_SOUND_UNS) $(SOUND_STR)
	@echo "Soundstripping" $@
	./$(SOUND_STR) $< $@
	@echo "Done"

help: info

info:
	@echo "This demo has no name yet v1.0"
	@echo "by Richard Cavell"
	@echo "make all"
	@echo "make clean"
	@echo "make disk"
	@echo "make info"	# Also make help
	@echo "make mame"
	@echo "make mame-debug"
	@echo "make xroar"

clean:
	@rm -f -v $(DISK) $(PART1) $(PART2) $(SOUND_STR)
	@rm -f -v $(PLUCK_SOUND_UNS) $(PLUCK_SOUND)
	@rm -f -v $(RJFC_SOUND_UNS) $(RJFC_SOUND)
	@rm -f -v $(TMD_SOUND_UNS) $(TMD_SOUND)

mame: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r"

mame-debug: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r" -debug

xroar: $(DISK)
	xroar -m coco2b -load-fd0 $(DISK) -type "RUN \"DEMO\"\r"
