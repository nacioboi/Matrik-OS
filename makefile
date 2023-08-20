ASM=nasm
CC=gcc -Wall
CC16=/usr/bin/watcom/binl/wcc
LD16=/usr/bin/watcom/binl/wlink

SRC_DIR=source
BUILD_DIR=built

.PHONY: all floppy_image kernel boot-loader clean always tools_fat

all: clean floppy_image tools_fat

#
# floppy_image
#
floppy_image: $(BUILD_DIR)/main_floppy.img
$(BUILD_DIR)/main_floppy.img: boot-loader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "MATRIK_OS" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/boot-loader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img test.txt "::test.txt"

#
# boot-loader
#
boot-loader: $(BUILD_DIR)/boot-loader.bin
$(BUILD_DIR)/boot-loader.bin: always
	$(ASM) $(SRC_DIR)/boot-loader/stage-1/boot.asm -f bin -o ${BUILD_DIR}/boot-loader.bin

#
# kernel
#
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o ${BUILD_DIR}/kernel.bin

#
# tools_fat
#
tools_fat: $(BUILD_DIR)/tools/fat
$(BUILD_DIR)/tools/fat: tools/fat/fat.c always
	$(CC) tools/fat/fat.c -g -o $(BUILD_DIR)/tools/fat

#
# always
#
always:
	mkdir -p built/tools

#
# clean
#
clean:
	rm -rf $(BUILD_DIR)/*