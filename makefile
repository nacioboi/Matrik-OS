ASM=nasm
CC=gcc -Wall
MAKE=make

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
	dd if=$(BUILD_DIR)/stage-1.boot.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/stage-2.boot.bin "::stage-2.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"

#
# boot-loader
#
boot-loader: stage-1 stage-2

stage-1: $(BUILD_DIR)/stage-1.boot.bin
$(BUILD_DIR)/stage-1.boot.bin: always
	$(MAKE) -C $(SRC_DIR)/boot-loader/stage-1 BUILD_DIR=$(abspath $(BUILD_DIR))

stage-2: $(BUILD_DIR)/stage-2.boot.bin
$(BUILD_DIR)/stage-2.boot.bin: always
	$(MAKE) -C $(SRC_DIR)/boot-loader/stage-2 BUILD_DIR=$(abspath $(BUILD_DIR))

#
# kernel
#
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: always
	$(MAKE) -C $(SRC_DIR)/kernel BUILD_DIR=$(abspath $(BUILD_DIR))
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