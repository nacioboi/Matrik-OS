BUILD_DIR?=build/
ASM?=nasm

.PHONY: all kernel

all: kernel

kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: kernel.asm
	$(ASM) kernel.asm -f bin -o $(BUILD_DIR)/kernel.bin