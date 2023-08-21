BUILD_DIR?=built/
ASM?=nasm

.PHONY: all stage-1

all: stage-1

stage-1: $(BUILD_DIR)/stage-1.boot.bin
$(BUILD_DIR)/stage-1.boot.bin: stage-1.boot.asm
	$(ASM) stage-1.boot.asm -f bin -o $(BUILD_DIR)/stage-1.boot.bin