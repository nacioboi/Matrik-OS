BUILD_DIR?=build/
ASM?=nasm
CC16?=/workspaces/Matrik-OS/tool-chain/watcom/binl/wcc
LD16?=/workspaces/Matrik-OS/tool-chain/watcom/binl/wlink
CFLAGS16?=-4 -d3 -s -wx -ms -zl -zq
ASMFLAGS?=-f obj

SOURCES_C=$(wildcard *.c)
SOURCES_ASM=$(wildcard *.asm)
OBJECTS_C=$(patsubst %.c, $(BUILD_DIR)/c.%.obj, $(SOURCES_C))
OBJECTS_ASM=$(patsubst %.asm, $(BUILD_DIR)/asm.%.obj, $(SOURCES_ASM))

.PHONY: all stage-2

all: stage-2

stage-2: $(BUILD_DIR)/stage-2.boot.bin
$(BUILD_DIR)/stage-2.boot.bin: $(OBJECTS_C) $(OBJECTS_ASM)
	$(LD16) NAME $(BUILD_DIR)/stage-2.boot.bin FILE \{ $(OBJECTS_ASM) $(OBJECTS_C) } OPTION MAP=$(BUILD_DIR)/stage-2.map @linker.lnk

$(BUILD_DIR)/c.%.obj: %.c
	$(CC16) $(CFLAGS16) -fo=$@ $< 

$(BUILD_DIR)/asm.%.obj: %.asm
	$(ASM) $(ASMFLAGS) -o $@ $<
