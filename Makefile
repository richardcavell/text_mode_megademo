# Makefile
# Part of Text Mode Megademo by Richard Cavell
# Still being written
# June-July 2025

DISK		=	TMMGDEMO.DSK
BASIC_PART	=	DEMO.BAS
PART1		=	PART1.BIN
PART2		=	PART2.BIN
PART3		=	PART3.BIN
PART4		=	PART4.BIN
PART5		=	PART5.BIN

PART1_SRC	= 	Part1.asm
PART2_SRC	= 	Part2.asm
PART3_SRC	=	Part3.asm
PART4_SRC	=	Part4.asm
PART5_SRC	=	Part5.asm

POP_SOUND	=	Sounds/Pop/Pop.raw
POP_SOUND_RES	=	Sounds/Pop/Pop_resampled.raw
POP_SOUND_SRC	=	Sounds/Pop/Mouth_pop.wav

TYPE_SOUND	=	Sounds/Type/Type.raw
TYPE_SOUND_RES	=	Sounds/Type/Model_M_resampled.raw
TYPE_SOUND_SRC	=	Sounds/Type/Model_M.wav

SNAP_SOUND	=	Sounds/Dot/Finger_Snap.raw
SNAP_SOUND_RES	=	Sounds/Dot/Finger_Snap_resampled.raw
SNAP_SOUND_SRC	=	Sounds/Dot/Finger_Snap.wav

NOW_SOUND	=	Sounds/Dot/Now.raw
NOW_SOUND_RES	=	Sounds/Dot/Now_resampled.raw
NOW_SOUND_SRC	=	Sounds/Dot/Now.wav

MOVE_SOUND	=	Sounds/Dot/Move.raw
MOVE_SOUND_RES	=	Sounds/Dot/Move_resampled.raw
MOVE_SOUND_SRC	=	Sounds/Dot/Move.wav

MMORE_SOUND	=	Sounds/Dot/Move_More.raw
MMORE_SOUND_RES	=	Sounds/Dot/Move_More_resampled.raw
MMORE_SOUND_SRC	=	Sounds/Dot/Move_More.wav

CHNGE_SOUND	=	Sounds/Dot/Change.raw
CHNGE_SOUND_RES	=	Sounds/Dot/Change_resampled.raw
CHNGE_SOUND_SRC	=	Sounds/Dot/Change.wav

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
CFLAGS	 += -Wduplicated-branches
CFLAGS   += -Werror=format-security -Werror=implicit-function-declaration
CFLAGS   += -Wfloat-equal -Wformat=2 -Wformat-overflow -Wformat-truncation
CFLAGS   += -Wjump-misses-init
CFLAGS   += -Wlogical-op -Wmissing-declarations -Wmissing-prototypes
CFLAGS   += -Wno-missing-field-initializers -Wnull-dereference
CFLAGS   += -Wold-style-definition
CFLAGS   += -Woverlength-strings -Wpointer-arith -Wredundant-decls -Wshadow
CFLAGS   += -Wsign-conversion -Wstack-protector -Wstrict-aliasing
CFLAGS   += -Wstrict-overflow=5 -Wswitch-default -Wswitch-enum
CFLAGS   += -Wundef -Wunreachable-code -Wunsafe-loop-optimizations
CFLAGS   += -fanalyzer -fstack-protector-strong
CFLAGS   += -g -O2
LDFLAGS   = -Wl,-z,defs -Wl,-O1 -Wl,--gc-sections -Wl,-z,relro -Wl,-z,now

# The toolshed is at https://toolshed.sourceforge.net/ToolShed.html
DECB		=	decb
RM		=	rm -f -v
ECHO		=	echo

MAME		=	mame
XROAR		=	xroar

.DEFAULT: all

.PHONY:	all clean disk help info license list test version
.PHONY: mame mame-debug xroar xroar-coco3 xroar-ntsc

all:	$(DISK) $(PART1) $(PART2) $(PART3) $(PART4) $(PART5)
all:	$(SIN_TABLE) $(SIN_GENERATOR)
all:	$(POP_SOUND) $(TYPE_SOUND) $(SNAP_SOUND)
all:	$(NOW_SOUND) $(MOVE_SOUND) $(MMORE_SOUND) $(CHNGE_SOUND)
all:	$(POP_SOUND_RES) $(TYPE_SOUND_RES)
all:	$(SNAP_SOUND_RES) $(NOW_SOUND_RES) $(MOVE_SOUND_RES)
all:	$(MMORE_SOUND_RES) $(CHNGE_SOUND_RES)
all:	$(SOUND_STR)

clean:
	@$(ECHO) "Removing all generated files" ...
	@$(RM) $(DISK) $(PART1) $(PART2) $(PART3) $(PART4) $(PART5)
	@$(RM) $(SIN_TABLE) $(SIN_GENERATOR)
	@$(RM) $(POP_SOUND) $(TYPE_SOUND) $(SNAP_SOUND)
	@$(RM) $(NOW_SOUND) $(MOVE_SOUND) $(MMORE_SOUND) $(CHNGE_SOUND)
	@$(RM) $(POP_SOUND_RES) $(TYPE_SOUND_RES)
	@$(RM) $(SNAP_SOUND_RES) $(NOW_SOUND_RES) $(MOVE_SOUND_RES)
	@$(RM) $(MMORE_SOUND_RES) $(CHNGE_SOUND_RES)
	@$(RM) $(SOUND_STR)
	@$(ECHO) ... Done

disk:	$(DISK)

$(DISK): $(BASIC_PART) $(PART1) $(PART2) $(PART3) $(PART4) $(PART5)
	@$(RM) $@
	@$(ECHO) "Compiling disk" $@ ...
	$(DECB) dskini $@ -3
	$(DECB) copy $(BASIC_PART) -0 -t -r $(DISK),$(BASIC_PART)
	$(DECB) copy -2 -b -r $(PART1) $(DISK),$(PART1)
	$(DECB) copy -2 -b -r $(PART2) $(DISK),$(PART2)
	$(DECB) copy -2 -b -r $(PART3) $(DISK),$(PART3)
	$(DECB) copy -2 -b -r $(PART4) $(DISK),$(PART4)
	$(DECB) copy -2 -b -r $(PART5) $(DISK),$(PART5)
	@$(DECB) free $@
	@$(ECHO) ... Done

$(PART1): $(PART1_SRC) $(POP_SOUND) $(TYPE_SOUND)
$(PART2): $(PART2_SRC)
$(PART3): $(PART3_SRC)
$(PART4): $(PART4_SRC) $(SIN_TABLE)
$(PART4): $(SNAP_SOUND) $(NOW_SOUND) $(MOVE_SOUND)
$(PART4): $(MMORE_SOUND) $(CHNGE_SOUND)
$(PART5): $(PART5_SRC)

$(PART1) $(PART2) $(PART3) $(PART4) $(PART5):
	@$(ECHO) Assembling $@ ...
	$(ASM) $(ASMFLAGS) -o $@ $<
	@$(ECHO) ... Done

$(SIN_TABLE): $(SIN_GENERATOR)
	@$(ECHO) "Generating sine table" ...
	./$< $@
	@$(ECHO) ... Done

$(POP_SOUND):	$(POP_SOUND_RES)
$(TYPE_SOUND): $(TYPE_SOUND_RES)
$(SNAP_SOUND): 	$(SNAP_SOUND_RES)
$(NOW_SOUND): 	$(NOW_SOUND_RES)
$(MOVE_SOUND): 	$(MOVE_SOUND_RES)
$(MMORE_SOUND): $(MMORE_SOUND_RES)
$(CHNGE_SOUND): $(CHNGE_SOUND_RES)

$(POP_SOUND) $(TYPE_SOUND) $(SNAP_SOUND): $(SOUND_STR)
$(NOW_SOUND) $(MOVE_SOUND) $(MMORE_SOUND) $(CHNGE_SOUND): $(SOUND_STR)

$(POP_SOUND) $(TYPE_SOUND) $(SNAP_SOUND) $(NOW_SOUND) \
$(MOVE_SOUND) $(MMORE_SOUND) $(CHNGE_SOUND):
	@$(ECHO) Soundstripping $@ ...
	./$(SOUND_STR) $< $@
	@$(ECHO) "... Done"

$(POP_SOUND_RES):   $(POP_SOUND_SRC)
$(TYPE_SOUND_RES):  $(TYPE_SOUND_SRC)
$(SNAP_SOUND_RES):  $(SNAP_SOUND_SRC)
$(NOW_SOUND_RES):   $(NOW_SOUND_SRC)
$(MOVE_SOUND_RES):  $(MOVE_SOUND_SRC)
$(MMORE_SOUND_RES): $(MMORE_SOUND_SRC)
$(CHNGE_SOUND_RES): $(CHNGE_SOUND_SRC)

$(POP_SOUND_RES) $(TYPE_SOUND_RES) $(SNAP_SOUND_RES) \
$(NOW_SOUND_RES) $(MOVE_SOUND_RES) $(MMORE_SOUND_RES) $(CHNGE_SOUND_RES):
	@$(RM) $@
	@$(ECHO) Resampling $@ ...
	ffmpeg -i $< -v warning -af "dynaudnorm=p=0.9:s=5,lowpass=f=3750,aresample=ochl=mono:osf=u8:osr=8192:dither_method=triangular" -f u8 -c:a pcm_u8 $@
	@$(ECHO) ... Done

$(SOUND_STR): $(SOUND_STR_SRC)
	@$(ECHO) Compiling $@ ...
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@
	@$(ECHO) ... Done

$(SIN_GENERATOR): $(SIN_GEN_SRC)
	@$(ECHO) Compiling $@ ...
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lm
	@$(ECHO) ... Done

help: info

info:
	@$(ECHO) "Text Mode Demo"
	@$(ECHO) "by Richard Cavell"
	@$(ECHO) "make all"
	@$(ECHO) "make clean"
	@$(ECHO) "make disk"
	@$(ECHO) "make info"	# Also make help and make list
	@$(ECHO) "make license"
	@$(ECHO) "make mame"
	@$(ECHO) "make mame-debug"
	@$(ECHO) "make version"
	@$(ECHO) "make xroar"	# Also make test
	@$(ECHO) "make xroar-coco3"
	@$(ECHO) "make xroar-ntsc"

license:
	@cat LICENSE

list:	info

test:	xroar

version:
	@$(ECHO)   "Text Mode Demo source: unversioned"
	@$(ASM)    --version       | head --lines=1
	@$(DECB)   2>&1 >/dev/null | head --lines=1
	@$(CC)     --version       | head --lines=1
	@$(MAME)   -help           | head --lines=1
	@./$(SIN_GENERATOR) -V	   | head --lines=1
	@./$(SOUND_STR) -V	   | head --lines=1
	@$(XROAR)  -V		   | head --lines=1

mame: $(DISK)
	$(MAME) coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r"

mame-debug: $(DISK)
	$(MAME) coco2b -flop1 $(DISK) -autoboot_delay 2 -autoboot_command "RUN \"DEMO\"\r" -debug

xroar: $(DISK)
	$(XROAR) -m coco2b -load-fd0 $(DISK) -type "RUN \"DEMO\"\r"

xroar-coco3: $(DISK)
	$(XROAR) -m coco3p -load-fd0 $(DISK) -type "RUN \"DEMO\"\r"

xroar-ntsc: $(DISK)
	$(XROAR) -m coco2bus -load-fd0 $(DISK) -type "RUN \"DEMO\"\r"
