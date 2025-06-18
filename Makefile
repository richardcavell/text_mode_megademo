# Makefile
# Part of Text Mode Demo by Richard Cavell
# v1.0
# June 2025

DISK		=	TMDEMO.DSK
BASIC_PART	=	DEMO.BAS
PART1		=	PART1.BIN
PART2		=	PART2.BIN

PART1_SRC	= 	Part1.asm
PART2_SRC	= 	Part2.asm

PLUCK_SOUND_SRC	=	Sounds/Pluck/Model_M.wav
PLUCK_SOUND_RES	=	Sounds/Pluck/Model_M_resampled.raw
PLUCK_SOUND	=	Sounds/Pluck/Pluck.raw

RJFC_SOUND_SRC	=	Sounds/RJFC_Presents_TMD/RJFC_Presents.wav
RJFC_SOUND_RES	=	Sounds/RJFC_Presents_TMD/RJFC_Presents_resampled.raw
RJFC_SOUND	=	Sounds/RJFC_Presents_TMD/RJFC_Presents.raw

TMD_SOUND_SRC	=	Sounds/RJFC_Presents_TMD/Text_Mode_Demo.wav
TMD_SOUND_RES	=	Sounds/RJFC_Presents_TMD/Text_Mode_Demo_resampled.raw
TMD_SOUND	=	Sounds/RJFC_Presents_TMD/Text_Mode_Demo.raw

SOUND_STR_SRC	=	sound_stripper.c
SOUND_STR	=	sound_stripper

SIN_GEN_SRC	=	sin_table_generator.c
SIN_GENERATOR	=	sin_table_generator
SIN_TABLE	=	sin_table.asm

# asm6809 is by Ciaran Anscomb
ASM		=	asm6809
ASMFLAGS	=	-C -v -8

# You can change this to your favorite C compiler
CC        =  gcc
CFLAGS    = -std=c89 -Wpedantic
CFLAGS   += -Wall -Wextra -Werror -fmax-errors=1
CFLAGS   += -Walloca -Wbad-function-cast -Wcast-align -Wcast-qual -Wconversion
CFLAGS   += -Wdisabled-optimization -Wdouble-promotion -Wduplicated-cond
CFLAGS   += -Werror=format-security -Werror=implicit-function-declaration
CFLAGS   += -Wfloat-equal -Wformat=2 -Wformat-overflow -Wformat-truncation
CFLAGS   += -Wlogical-op -Wmissing-prototypes -Wmissing-declarations
CFLAGS   += -Wno-missing-field-initializers -Wnull-dereference
CFLAGS   += -Woverlength-strings -Wpointer-arith -Wredundant-decls -Wshadow
CFLAGS   += -Wsign-conversion -Wstack-protector -Wstrict-aliasing
CFLAGS   += -Wstrict-overflow -Wswitch-default -Wswitch-enum
CFLAGS   += -Wundef -Wunreachable-code -Wunsafe-loop-optimizations
CFLAGS   += -fstack-protector-strong
CFLAGS   += -g -O2
LDFLAGS   = -Wl,-z,defs -Wl,-O1 -Wl,--gc-sections -Wl,-z,relro

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

$(PART1): $(PART1_SRC) $(SIN_TABLE) $(PLUCK_SOUND) $(RJFC_SOUND) $(TMD_SOUND)
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

$(PLUCK_SOUND_RES): $(PLUCK_SOUND_SRC)
	@rm -v -f $@
	@echo "Resampling" $@
	ffmpeg -i $< -v warning -af "acrusher=bits=6,lowpass=f=3750,aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular" -f u8 -c:a pcm_u8 $@
	@echo "Done"

$(PLUCK_SOUND): $(PLUCK_SOUND_RES) $(SOUND_STR)
	@echo "Soundstripping" $@
	./$(SOUND_STR) $< $@
	@echo "Done"

$(RJFC_SOUND_RES): $(RJFC_SOUND_SRC)
	@rm -v -f $@
	@echo "Resampling" $@
	ffmpeg -i $< -v warning -af "acrusher=bits=6,lowpass=f=3750,aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular" -f u8 -c:a pcm_u8 $@
	@echo "Done"

$(RJFC_SOUND): $(RJFC_SOUND_RES) $(SOUND_STR)
	@echo "Soundstripping" $@
	./$(SOUND_STR) $< $@
	@echo "Done"

$(TMD_SOUND_RES): $(TMD_SOUND_SRC)
	@rm -v -f $@
	@echo "Resampling" $@
	ffmpeg -i $< -v warning -af "acrusher=bits=6,lowpass=f=3750,aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular" -f u8 -c:a pcm_u8 $@
	@echo "Done"

$(TMD_SOUND): $(TMD_SOUND_RES) $(SOUND_STR)
	@echo "Soundstripping" $@
	./$(SOUND_STR) $< $@
	@echo "Done"

$(SIN_GENERATOR): $(SIN_GEN_SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $< -lm

$(SIN_TABLE): $(SIN_GENERATOR)
	./$< $@

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
	@rm -f -v $(PLUCK_SOUND_RES) $(PLUCK_SOUND)
	@rm -f -v $(RJFC_SOUND_RES) $(RJFC_SOUND)
	@rm -f -v $(TMD_SOUND_RES) $(TMD_SOUND)
	@rm -f -v $(SIN_GENERATOR) $(SIN_TABLE)

mame: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r"

mame-debug: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r" -debug

xroar: $(DISK)
	xroar -m coco2b -load-fd0 $(DISK) -type "RUN \"DEMO\"\r"
