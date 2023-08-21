#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive)
{
	puts("Hello world from c! :D\r\n");
	printf("Formatted using our implementation of `printf`: %% %c %s\r\n", 'a', "string");
	for (;;)
		;
}
