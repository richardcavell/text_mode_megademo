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

RJFC_SOUND_SRC	=	Sounds/RJFC_Presents_TMD/RJFC_Presents_TMD.wav
RJFC_SOUND_RES	=	Sounds/RJFC_Presents_TMD/RJFC_Presents_TMD_resampled.raw
RJFC_SOUND	=	Sounds/RJFC_Presents_TMD/RJFC_Presents_TMD.raw

SOUND_STR	=	sound_stripper
SOUND_STR_SRC	=	sound_stripper.c

SIN_TABLE	=	sin_table.asm
SIN_GENERATOR	=	sin_table_generator
SIN_GEN_SRC	=	sin_table_generator.c

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

.PHONY:	all clean disk help info license mame mame-debug xroar

all:	$(DISK) $(PART1) $(PART2)
all:	$(SIN_GENERATOR) $(SIN_TABLE)
all:	$(PLUCK_SOUND) $(RJFC_SOUND)
all:	$(PLUCK_SOUND_RES) $(RJFC_SOUND_RES)
all:	$(SOUND_STR)

disk:	$(DISK)

$(DISK): $(BASIC_PART) $(PART1) $(PART2)
	@rm -f -v $@
	@echo "Compiling disk" $@ ...
	decb dskini $@ -3
	decb copy $(BASIC_PART) -0 -t -r $(DISK),$(BASIC_PART)
	decb copy -2 -b -r $(PART1) $(DISK),$(PART1)
	decb copy -2 -b -r $(PART2) $(DISK),$(PART2)
	@echo "... Done"

$(PART1): $(PART1_SRC) $(SIN_TABLE) $(PLUCK_SOUND) $(RJFC_SOUND)
$(PART2): $(PART2_SRC)

$(PART1) $(PART2):
	@echo "Assembling" $@ ...
	$(ASM) $(ASMFLAGS) -o $@ $<
	@echo "... Done"

$(SIN_TABLE): $(SIN_GENERATOR)
	@echo "Generating sine table ..."
	./$< $@
	@echo "... Done"

$(PLUCK_SOUND): $(PLUCK_SOUND_RES)
$(RJFC_SOUND): $(RJFC_SOUND_RES)

$(PLUCK_SOUND) $(RJFC_SOUND): $(SOUND_STR)

$(PLUCK_SOUND) $(RJFC_SOUND):
	@echo "Soundstripping" $@ ...
	./$(SOUND_STR) $< $@
	@echo "... Done"

$(RJFC_SOUND_RES): $(RJFC_SOUND_SRC)
$(PLUCK_SOUND_RES): $(PLUCK_SOUND_SRC)

$(RJFC_SOUND_RES) $(PLUCK_SOUND_RES):
	@rm -v -f $@
	@echo "Resampling" $@ ...
	ffmpeg -i $< -v warning -af "lowpass=f=3750,aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular" -f u8 -c:a pcm_u8 $@
	@echo "... Done"

$(SOUND_STR): $(SOUND_STR_SRC)
	@echo "Compiling" $@ ...
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@
	@echo "... Done"

$(SIN_GENERATOR): $(SIN_GEN_SRC)
	@echo "Compiling" $@ ...
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lm
	@echo "... Done"

help: info

info:
	@echo "Text Mode Demo v1.0"
	@echo "by Richard Cavell"
	@echo "make all"
	@echo "make clean"
	@echo "make disk"
	@echo "make info"	# Also make help
	@echo "make license"
	@echo "make mame"
	@echo "make mame-debug"
	@echo "make xroar"

license:
	@cat LICENSE

clean:
	@echo "Removing all generated files ..."
	@rm -f -v $(DISK) $(PART1) $(PART2)
	@rm -f -v $(SIN_GENERATOR) $(SIN_TABLE)
	@rm -f -v $(PLUCK_SOUND) $(RJFC_SOUND)
	@rm -f -v $(PLUCK_SOUND_RES) $(RJFC_SOUND_RES)
	@rm -f -v $(SOUND_STR)
	@echo "... Done"

mame: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r"

mame-debug: $(DISK)
	mame coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r" -debug

xroar: $(DISK)
	xroar -m coco2b -load-fd0 $(DISK) -type "RUN \"DEMO\"\r"
