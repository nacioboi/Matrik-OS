#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef uint8_t bool;
#define true 1
#define false 0

typedef struct {
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntriesCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    // extended boot record.
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;
    uint8_t VolumeLabel[11];
    uint8_t SystemId[8];
} __attribute__((packed)) BootSector;

typedef struct {
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirEntry;

BootSector g_BootSector;
uint8_t *g_Fat;
DirEntry *g_RootDirectory;
uint32_t g_RootDirEnd;

bool readBootSector(FILE *disk) {
	return fread(&g_BootSector, sizeof(g_BootSector), 1, disk) > 0;
}

bool dread(FILE *disk, uint32_t lba, uint32_t count, void *bufferOut) {
	bool ok = true;
	ok = ok && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);
	ok = ok && (fread(bufferOut, g_BootSector.BytesPerSector, count, disk) == count);
	return ok;
}

bool readFat(FILE *disk) {
	g_Fat = (uint8_t*) malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
	return dread(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_Fat);
}

bool readRootDirectory(FILE *disk) {
	uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount;
	uint32_t size = sizeof(DirEntry) * g_BootSector.DirEntriesCount;
	uint32_t sectors = (size / g_BootSector.BytesPerSector);
	if (size % g_BootSector.BytesPerSector > 0) {
		sectors++;
	}
	g_RootDirEnd = lba + sectors;
	g_RootDirectory = (DirEntry*) malloc(sectors * g_BootSector.BytesPerSector);
	return dread(disk, lba, sectors, g_RootDirectory);
}

DirEntry * findFile(const char *name) {
	for (uint32_t i = 0; i < g_BootSector.DirEntriesCount; i++) {
		if (memcmp(name, g_RootDirectory[i].Name, 11) == 0) {
			return &g_RootDirectory[i];
		}
	}

	return NULL;
}

bool readFile(DirEntry *entry, FILE *disk, uint8_t *outputBuffer) {
	bool ok = true;
	uint16_t currentCluster = entry->FirstClusterLow;

	do {
		uint32_t lba = g_RootDirEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster;
		ok = ok && dread(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer);
		outputBuffer += g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector;

		uint32_t fatIndex = currentCluster * 3 / 2;
		if (currentCluster % 2 == 0) {
			currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) & 0x0FFF;
		} else {
			currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) >> 4;
		}
	} while (ok && currentCluster < 0xFF8);

	return ok;
}

int main(int argc, char **argv) {
	if (argc < 3) {
		printf("Syntax: %s <disk image> <file name>\n", argv[0]);
		return -1;
	}

	FILE *disk = fopen(argv[1], "rb");
	if (!disk) {
		fprintf(stderr, "cannot open disk.\n");
		return -2;
	}

	if (!readBootSector(disk)) {
		fprintf(stderr, "cannot read disk.\n");
		return -3;
	}

	if (!readFat(disk)) {
		fprintf(stderr, "cannot read fat.\n");
		free(g_Fat);
		return -4;
	}

	if (!readRootDirectory(disk)) {
		fprintf(stderr, "cannot read root.\n");
		free(g_Fat);
		free(g_RootDirectory);
		return -5;
	}

	DirEntry *entry = findFile(argv[2]);
	if (!entry) {
		fprintf(stderr, "cannot find file.\n");
		free(g_Fat);
		free(g_RootDirectory);
		return -6;
	}

	uint8_t *buffer = (uint8_t*) malloc(entry->Size + g_BootSector.BytesPerSector);
	if (!readFile(entry, disk, buffer)) {
		fprintf(stderr, "cannot read file.\n");
		free(g_Fat);
		free(g_RootDirectory);
		free(buffer);
		return -7;
	}

	for (size_t i = 0; i < entry->Size; i++) {
		if (isprint(buffer[i])) {
			fputc(buffer[i], stdout);
		} else {
			printf("<%02X>", buffer[i]);
		}

	}

	printf("\n");

	free(g_Fat);
	free(g_RootDirectory);
	
	return 0;
}