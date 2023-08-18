ASM=nasm
SRC_DIR=source
BUILD_DIR=built

.PHONY: all floppy_image kernel bootloader clean always

#
# floppy_image
#
floppy_image: $(BUILD_DIR)/main_floppy.img:
$(BUILD_DIR)/main_floppy.img: bootloader kernel
	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
	truncate -s 1440k $(BUILD_DIR)/main_floppy.img

#
# bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin
$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/boot-loader/boot.asm -f bin -o ${BUILD_DIR}/bootloader.bin

#
# kernel
#
kernel: $(BUILD_DIR)/kernel.bin
$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o ${BUILD_DIR}/kernel.bin

#
# always
#
always:
	mkdir built

#
# clean
#
clean:
	rm -rf $(BUILD_DIR)/*