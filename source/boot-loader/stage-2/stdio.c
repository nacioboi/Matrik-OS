#include "stdio.h"
#include "x86.h"
#include "bool.h"

void putc(char c)
{
	x86_Video_WriteCharTeletype(c, 0);
}

void puts(const char *str)
{
	while (*str)
	{
		putc(*str++);
	}
}

#define PRINTF_STATE_NORMAL 0
#define PRINTF_STATE_LENGTH 1
#define PRINTF_STATE_LENGTH_SHORT 2
#define PRINTF_STATE_LENGTH_LONG 3
#define PRINTF_STATE_SPEC 4

#define PRINTF_LENGTH_DEFAULT 0
#define PRINTF_LENGTH_SHORT_SHORT 1
#define PRINTF_LENGTH_SHORT 2
#define PRINTF_LENGTH_LONG 4

int *printf_number(int *argp, int length, bool sign, int radix);

void _cdecl printf(const char *fmt, ...)
{
	int *argp = (int *)&fmt;
	int state = PRINTF_STATE_NORMAL;
	int length = PRINTF_LENGTH_DEFAULT;
	int radix = 10;
	bool sign = false;

	argp++;

	while (*fmt)
	{
		if (state == PRINTF_STATE_NORMAL)
		{
			if (*fmt == '%')
			{
				state = PRINTF_STATE_LENGTH;
			}
			else
			{
				putc(*fmt);
			}
		}
		else if (state == PRINTF_STATE_LENGTH)
		{
			if (*fmt == 'h')
			{
				length = PRINTF_LENGTH_SHORT;
				state = PRINTF_STATE_LENGTH_SHORT;
			}
			else if (*fmt == 'l')
			{
				length = PRINTF_LENGTH_LONG;
				state = PRINTF_STATE_SPEC;
			}
			else
			{
				goto PRINTF_STATE_SPEC_;
			}
		}
		else if (state == PRINTF_STATE_LENGTH_SHORT)
		{
			if (*fmt == 'h')
			{
				length = PRINTF_LENGTH_SHORT_SHORT;
				state = PRINTF_STATE_SPEC;
			}
			else
			{
				goto PRINTF_STATE_SPEC_;
			}
		}
		else if (state == PRINTF_STATE_SPEC)
		{
		PRINTF_STATE_SPEC_:
			if (*fmt == 'c')
			{
				putc((char)*argp++);
			}
			else if (*fmt == 's')
			{
				puts(*(char **)argp++);
			}
			else if (*fmt == '%')
			{
				putc('%');
			}
			else if (*fmt == 'i' || *fmt == 'd')
			{
				radix = 10;
				sign = true;
				argp = printf_number(argp, length, sign, radix);
			}
			else if (*fmt == 'u')
			{
				radix = 10;
				sign = false;
				argp = printf_number(argp, length, sign, radix);
			}
			else if (*fmt == 'X' || *fmt == 'x' || *fmt == 'p')
			{
				radix = 16;
				sign = false;
				argp = printf_number(argp, length, sign, radix);
			}
			else if (*fmt == 'o')
			{
				radix = 8;
				sign = false;
				argp = printf_number(argp, length, sign, radix);
			}

			state = PRINTF_STATE_NORMAL;
			length = PRINTF_LENGTH_DEFAULT;
			radix = 10;
			sign = false;
		}
		fmt++;
	}
}

const char g_HexChars[] = "0123456789abcdef";

int *printf_number(int *argp, int length, bool sign, int radix)
{
	char buffer[32];
	unsigned long long number;
	int number_sign = 1;
	int pos = 0;

	if (length == PRINTF_LENGTH_SHORT_SHORT || length == PRINTF_LENGTH_SHORT || length == PRINTF_LENGTH_DEFAULT)
	{
		if (sign)
		{
			int n = *argp;
			if (n < 0)
			{
				n = -n;
				number_sign = -1;
			}
			number = (unsigned long long)n;
		}
		else
		{
			number = *(unsigned long int *)argp;
		}
		argp++;
	}
	else if (length == PRINTF_LENGTH_LONG)
	{
		if (sign)
		{
			long int n = *(long int *)argp;
			if (n < 0)
			{
				n = -n;
				number_sign = -1;
			}
			number = (unsigned long long)n;
		}
		else
		{
			number = *(unsigned long long int *)argp;
		}
		argp += 2;
	}

	// convert to string
	do
	{
		uint32_t rem;
		x86_div_64_32(number, radix, &number, &rem);
		buffer[pos++] = g_HexChars[rem];
	} while (number > 0);

	if (sign && number_sign < 0)
	{
		buffer[pos++] = '-';
	}

	while (--pos >= 0)
	{
		putc(buffer[pos]);
	}

	return argp;
}
